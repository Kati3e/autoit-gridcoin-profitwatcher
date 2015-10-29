#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

; Katiee's GRC Profit Margin Watcher v0.2 (October 25th, 2015)
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
;
; Coded by: Katiee
;    Find me on IRC @ irc://irc.freenode.net/#gridcoin
;

#include <String.au3>
#include <Array.au3>
#include <Timers.au3>

; User Settings (Edit These!)
$watchAlert = TRUE ; Display a Message Box when Profit Margin has been reached
$grcCoins = 20000 ; Amount of Coin you hold or want to track
$grcBoughtPrice = 0.00002300 ; The price at which you want to value the coins in the past (in BTC)
$btcBoughtPrice = 275 ; The price at which you want to value the coins in the past (in USD)
$watchProfit = 75 ; The profit margin you want to watch for (in USD)
$loopInterval = 60000 ; How often to check APIs (in Milliseconds)

; Lets not spam the APIs with "Auto-It" headers
HttpSetUserAgent('Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)')

; API URLs
$coinbase_api = "https://api.coinbase.com/v1/prices/spot_rate?currency=USD"
$bittrex_api = "https://bittrex.com/api/v1.1/public/getticker?market=btc-grc"

$error = FALSE
$errorMsg = ""

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
	Else
		; Find profit
		$grc_btc_boughtPrice = $grcCoins * $grcBoughtPrice * $btcBoughtPrice
		$grc_btc_currentPrice = $grcCoins * $coinbasePrice * $bittrexBid
		$profit = $grc_btc_currentPrice - $grc_btc_boughtPrice

		; Output Results to Console
		ConsoleWrite("BTC: $" & $coinbasePrice & " | GRC: (Bid: " & $bittrexBid & " | Ask: " & $bittrexAsk & " | Last: " & _
						$bittrexLast & ")" & @CRLF & "   Your Profit Margin: $" & $profit & @CRLF)

		; Check Watch Profit (don't display message box if PC is idle, so script continues to run)
		If ($watchAlert) AND ($profit >= $watchProfit) AND (_Timer_GetIdleTime() < 300000) Then
			MsgBox(0, "Alert", "GRC has hit your profit margin")
		EndIf
	EndIf

	$error = FALSE ; Reset $error value

	; Sleep for $loopInterval before repeating
	Sleep($loopInterval)
WEnd


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
