#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

; Katiee's GRC Profit Margin Watcher v0.3 (October 29th, 2015)
;
; 	This script watches BTC-USD and BTC-GRC Prices and alerts you to profit margins based on the price you bought
; into BTC and GRC in the past. Please edit the "User Settings" for your own profit margins.
;
;	Compile as CommandLine-UI (CUI) for Console Output or Run in SciTE
;
; To-do:
;    Save settings to ini and add script inputs
;    Add other exchanges
;    Add email/text alerts
;    Simplify error handling
;
; Changes:
;    v0.2: Added error handling, should be no more crashes, please report any crashes to me.
;    v0.3: Added data logging and a graph.
;
; Coded by: Katiee
;    Find me on IRC @ irc://irc.freenode.net/#gridcoin
;

#include "GraphGDIPlus.au3" ; https://www.autoitscript.com/forum/topic/104399-graphgdiplus-udf-create-gdi-line-graphs/
#include <String.au3>
#include <Array.au3>
#include <Timers.au3>
#include <File.au3>
#include <Date.au3>

Opt("GUIOnEventMode", 1)

; User Settings (Edit These!)
$watchAlert = TRUE ; Display a Message Box when Profit Margin has been reached
$grcCoins = 20000 ; Amount of Coin you hold or want to track
$grcBoughtPrice = 0.00002300 ; The price at which you want to value the coins in the past (in BTC)
$btcBoughtPrice = 275 ; The price at which you want to value the coins in the past (in USD)
$watchProfit = 75 ; The profit margin you want to watch for (in USD)
$loopInterval = 60000 ; How often to check APIs (in Milliseconds)
$logOutput = TRUE ; Log console output to file?

; Lets not spam the APIs with "Auto-It" headers
HttpSetUserAgent('Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)')

; API URLs
$coinbase_api = "https://api.coinbase.com/v1/prices/spot_rate?currency=USD"
$bittrex_api = "https://bittrex.com/api/v1.1/public/getticker?market=btc-grc"

$error = FALSE
$errorMsg = ""



; Graph Stuff
$GUI = GUICreate("",1200,600)
GUISetOnEvent(-3,"_Exit")
GUISetState()

;----- Create Graph area -----
$Graph = _GraphGDIPlus_Create($GUI,40,30,1130,520,0xFF000000,0xFF88B3DD)

_Draw_Graph()

While 1 ; Main Loop
	; Request APIs
	$sDataCoinbase = errorHandling(BinaryToString(InetRead($coinbase_api)), "Coinbase")
	If @error Then ContinueLoop

	$sDataBittrex = errorHandling(BinaryToString(InetRead($bittrex_api)), "Bittrex")
	If @error Then ContinueLoop

	; Find Coinbase BTC Price
	$coinbasePrice = processData($sDataCoinbase, '"amount":"', '"', 'Coinbase')

	; Find Bittrex GRC-BTC Prices
	$bittrexBid = processData($sDataBittrex, '"Bid":', ',', 'Bittrex')
	$bittrexAsk = processData($sDataBittrex, '"Ask":', ',', 'Bittrex')
	$bittrexLast = processData($sDataBittrex, '"Last":', '}', 'Bittrex')

	If $error Then
		ConsoleWrite($errorMsg & @CRLF)
		writeFile(@ScriptDir & "\errors.log", "[" &  _Now() & "] " & $errorMsg)
	Else
		; Find profit
		$grc_btc_boughtPrice = $grcCoins * $grcBoughtPrice * $btcBoughtPrice
		$grc_btc_currentPrice = $grcCoins * $coinbasePrice * $bittrexBid
		$profit = $grc_btc_currentPrice - $grc_btc_boughtPrice

		; Save results to disk
		writeFile(@ScriptDir & "\data.log", _Now() & "|" & $coinbasePrice & "|" & $bittrexBid & "|" & $bittrexAsk & "|" & $bittrexLast & _
			"|" & $profit)

		; Output Results to Console
		ConsoleWrite("BTC: $" & $coinbasePrice & " | GRC: (Bid: " & $bittrexBid & " | Ask: " & $bittrexAsk & " | Last: " & _
						$bittrexLast & ")" & @CRLF & "   Your Profit Margin: $" & $profit & @CRLF)

		; Log results to file
		If ($logOutput) Then
			writeFile(@ScriptDir & "\output.log", "[" &  _Now() & "] BTC: $" & $coinbasePrice & " | GRC: (Bid: " & $bittrexBid & " | Ask: " & _
							$bittrexAsk & " | Last: " & $bittrexLast & ")" & @CRLF & "   Your Profit Margin: $" & $profit)
		EndIf

		_Draw_Graph()

		; Check Watch Profit (don't display message box if PC is idle, so script continues to run)
		If ($watchAlert) AND ($profit >= $watchProfit) AND (_Timer_GetIdleTime() < 300000) Then
			MsgBox(0, "Alert", "GRC has hit your profit margin")
		EndIf
	EndIf

	$error = FALSE ; Reset $error value

	; Sleep for $loopInterval before repeating
	wait($loopInterval)
WEnd

Func wait($time)
	$i = 0
	While $i < $time
		_GraphGDIPlus_Refresh($Graph)
		Sleep(100)
		$i = $i + 100
	WEnd
EndFunc

Func writeFile($fileName, $data)
	$file = FileOpen($fileName , 1)
	FileWrite($file, $data & @CRLF)
	FileClose($file)
EndFunc


; Check the API's reply for any errors
Func errorHandling($apiResult, $apiName)
	If $apiResult = "" Then
		ConsoleWrite("     Error with " & $apiName & " API: Request timed out" & @CRLF)
		Sleep($loopInterval)
		Return SetError(1, "", "Timed Out")
	Else
		Return $apiResult
	EndIf
EndFunc

; Process the API's reply
Func processData($apiResult, $startString, $endString, $apiName)
	$array = _StringBetween($apiResult, $startString, $endString)
	If @error Then ; _StringBetween error checking
		$errorMsg = "     Error with " & $apiName & " API: " & $apiResult
		$error = TRUE
		Return "error"
	Else
		Return $array[0]
	EndIf
EndFunc


; Graph Funcs

Func _Draw_Graph()
	;sleep(1000)
	; Read data file
	Dim $aArray
	_FileReadToArray(@ScriptDir & "/data.log", $aArray, 1, "|")

	$max = _ArrayMax($aArray, 1, 1, -1, 5)
	$min = _ArrayMin($aArray, 1, 1, -1, 5)

	$diff = $max - $min

	_GraphGDIPlus_Clear($Graph)
	;_GraphGDIPlus_Refresh($Graph)


	;sleep(5000)

	;----- Set X axis range from -5 to 5 -----
	_GraphGDIPlus_Set_RangeX($Graph,0,$aArray[0][0]-1,0,0,0)
	_GraphGDIPlus_Set_RangeY($Graph,$min,$max,10,1,2)

	;----- Set Y axis range from -5 to 5 -----
	;_GraphGDIPlus_Set_GridX($Graph,1,0xFF6993BE)
	_GraphGDIPlus_Set_GridY($Graph,$diff/10,0xFF6993BE)

    ;----- Set line color and size -----
    _GraphGDIPlus_Set_PenColor($Graph,0xFF325D87)
    _GraphGDIPlus_Set_PenSize($Graph,2)

    ;----- draw lines -----
    $First = True
    For $i = 1 to $aArray[0][0] Step 1
        If $First = True Then _GraphGDIPlus_Plot_Start($Graph,$i,$aArray[$i+1][5])
        $First = False
        _GraphGDIPlus_Plot_Line($Graph,$i-1,$aArray[$i][5])

    Next

	_GraphGDIPlus_Refresh($Graph)
EndFunc

Func _Exit()
    ;----- close down GDI+ and clear graphic -----
    _GraphGDIPlus_Delete($GUI,$Graph)
    Exit
EndFunc
