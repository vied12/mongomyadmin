# -----------------------------------------------------------------------------
# Project : Portfolio - Compass Productions
# -----------------------------------------------------------------------------
# Author : Edouard Richard                                  <edou4rd@gmail.com>
# Author : Olivier Chardin                                <jegrandis@gmail.com>
# -----------------------------------------------------------------------------
# License : GNU Lesser General Public License
# -----------------------------------------------------------------------------
# Creation : 01-Sep-2012
# Last mod : 01-Sep-2012
# -----------------------------------------------------------------------------

window.serious.format = {}

class serious.format.StringFormat
	@Capitalize: (str) ->
		if str? and str != ""
			str.replace(/\w\S*/g, (txt) ->
				return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
			)
		else
			return null

class serious.format.NumberFormat
	@SecondToString: (seconds) ->
		hours   = parseInt(seconds / 3600 ) % 24
		minutes = parseInt(seconds / 60 ) % 60
		seconds = parseInt(seconds % 60, 10)
		if hours   < 10
			hours   = "0"+hours
		if minutes < 10
			minutes = "0"+minutes
		if seconds < 10
			seconds = "0"+seconds
		if hours == "00"
			return minutes+":"+seconds
		else
			return hours+":"+minutes+":"+seconds