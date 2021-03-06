Include dtCommon

/// <p>v2.0.0</p>
/// <p><b>Scrapes a given URI and stores scraping fragment in database.</b></p>
/// <p><b>Dependacies:</b> DTI's common (dtCommon.inc) macros.</p>
/// <p>Developed by Micky Hulse for <a href="http://www.registerguard.com">The Register-Guard</a>.</p>
/// <p>Please visit <a href="https://github.com/registerguard/custom.rg.Scraper">GitHub</a> for more information and/or to get the latest version of this code.</p>
Class custom.rg.Scraper Extends %Persistent
{

/// <p><b>Name</b> of scraping "fragment" (required).</p>
Property name As %String(MAXLEN = 255) [ Required, SqlColumnNumber = 2 ];

/// <p><b>Interval</b> of scraping in minutes (required).</p>
Property interval As %Integer(MAXVAL = 525600, MINVAL = 1) [ Required, SqlColumnNumber = 3 ];

/// <p><b>First</b> time scraped (required).</p>
Property first As %TimeStamp [ Required, SqlColumnNumber = 4 ];

/// <p><b>Date/time</b> of last scraping (required).</p>
Property scraped As %TimeStamp [ Required, SqlColumnNumber = 5 ];

/// <p><b>Counts</b> how many times scraping has been updated.</p>
Property counter As %Integer [ Required, SqlColumnNumber = 6 ];

/// <p><b>Contents</b> of scraping.</p>
Property scraping As %Stream.GlobalCharacter [ SqlColumnNumber = 7 ];

/// <p><b>URI</b> of scraping (required).</p>
Property uri As %String(MAXLEN = 1024) [ Required, SqlColumnNumber = 8 ];

/// <p><b>Note:</b> IdKey can't be updated; you need to delete and re-insert the row.</p>
Index IDKEY On name [ IdKey ];

/// <p><b>Parameters:</b></p>
/// <ul>
/// <li><b>name:</b> <i>(Required)</i> Scraping fragment identifier.</li>
/// <li><b>server:</b> <i>(Required)</i> The IP address or machine name of the web server that you wish to connect to.<b>*</b></li>
/// <li><b>location:</b> The location is the url to request, e.g. '/test.html'. This can contain parameters which are assumed to be already URL escaped.<b>*</b></li>
/// <li><b>interval:</b> Time, in minutes, of scraping interval. <b>Default:</b> 60 minutes.</li>
/// <li><b>force:</b> Force scraping fragment update? <b>Default:</b> False (0).</li>
/// <li><b>userAgent:</b> The User-Agent request-header field contains information about the user agent originating the request.<b>*</b></li>
/// <li><b>followRedirect:</b> If true then automatically follow redirection requests from the web server. <b>Default:</b> False (0).<b>*</b></li>
/// <li><b>https:</b> If not using a proxy server and this is true then it issues a request for an https page rather than the normal http page. <b>Default:</b> False (0).<b>*</b></li>
/// <li><b>authorization:</b> Sets/get the 'Authorization:' header field in the Http request.<b>*</b></li>
/// <li><b>contentEncoding:</b> Sets/gets the 'Content-Encoding:' entity header field in the HTTP request.<b>*</b></li>
/// <li><b>contentType:</b> Sets/gets the 'Content-Type:' entity header field in the HTTP request. <b>Default:</b> "text/html".<b>*</b></li>
/// <li><b>contentCharset:</b> If the ContentType starts with 'text/' then this is the charset to encode the contents with. <b>Default:</b> UTF-8.<b>*</b></li>
/// <li><b>port:</b> The TCP/IP port number to connect to. <b>Default:</b> 80.<b>*</b></li>
/// <li><b>pragma:</b> The Pragma general-header field is used to include implementation- specific directives that may apply to any recipient along the request/response chain.<b>*</b></li>
/// </ul>
/// <p><b>*</b> See <class>%Net.HttpRequest</class> for more info.</p>
ClassMethod scrape(
	name As %String = "",
	server As %String = "",
	location As %String = "",
	interval As %Integer = 60,
	force As %Boolean = 0,
	userAgent As %String = "",
	followRedirect As %Boolean = 0,
	https As %Boolean = 0,
	authorization As %String = "",
	contentEncoding As %String = "",
	contentType As %String = "text/html",
	contentCharset As %String = "UTF-8",
	port As %Integer = 80,
	pragma As %String = "") As %String
{
	; Initialize variables:
	set return  = ""    // Return string.
	set sc      = $$$OK // Status code.
	set stream  = ""    // DT global character stream.
	set scraper = ""    // Stream from database.
	set http    = ""    // Net http request.
	set uri     = ""    // URI of scraping.
	
	; Make sure interval is a whole number:
	set interval = $normalize(interval, -1) // When scale=-1, num is truncated to an integer value.
	
	; Name/server required:
	if ($length(name) && $length(server) && (interval > 0)) {
		
		; Initialize global character stream object:
		//set stream = ##class(%Stream.GlobalCharacter).%New()
		set stream = ##class(dt.common.streams.GlobalCharacterStream).%New() // https://groups.google.com/d/topic/dti-lightning/hagUO0vUq0c/discussion
		
		; Open the Scraper object:
		set scraper = ..%OpenId(name,, .sc)
		
		; IF there's a status error ($isobject(scraper) would also work) OR an expired object OR force is true:
		if ($$$ISERR(sc) || ($isobject(scraper) && scraper.expired()) || force) {
			
			; Re-initialize:
			set sc = $$$OK
			
			; %Net.HttpRequest stuff:
			set http = ##class(%Net.HttpRequest).%New()
			set http.Server = server
			//set:($length(location)) http.Location = location // Note the location does not contain a leading '/' character as this is implicit.
			set:($length(userAgent)) http.UserAgent = userAgent
			//set:($length(params)) http.Params = params // Appears to be useless: http://tinyurl.com/4gpyvx7
			set:(followRedirect) http.FollowRedirect = followRedirect
			set:(https) http.Https = https
			set:($length(authorization)) http.Authorization = authorization
			set:($length(contentEncoding)) http.ContentEncoding = contentEncoding
			set http.ContentType = contentType
			set http.ContentCharset = contentCharset
			set http.Port = port
			set:($length(pragma)) http.Pragma = pragma
			//set http.XXXX = xxxxxxx
			
			; Get the request:
			set sc = http.Get(location)
			
			; Was the request "fulfilled"?
			if ($$$ISOK(sc) && (http.HttpResponse.StatusCode = 200)) {
				
				; Fully retrieve stream:
				while( ' http.HttpResponse.Data.AtEnd) {
					
					; Populate character stream:
					do stream.Write(http.HttpResponse.Data.Read())
					
				}
				
				; Rewind the stream before reading it:
				do stream.Rewind() // Probably overkill, but it can't hurt.
				
				; Build request URI:
				set uri = $case(http.Https, 1:"https", :"http") _ "://" _ http.Server _ $case(http.Port, 80:"", :":" _ http.Port) _ "/" _ $zstrip(location, "<", "/") // Should I EscapeURL too?
				
				; Validate interval:
				set:(interval > 525600) interval = 525600 // (24 * 60) * 365 = 525600 minutes/year.
				
				; Updating an existing entry?
				if ($isobject(scraper)) {
					
					; Yes:
					set scraper.interval = interval
					set scraper.scraped = $zdatetime($horolog, 3)
					set scraper.counter = scraper.counter + 1
					//set scraper.scraping = stream
					set sc = scraper.scraping.CopyFrom(stream)
					set scraper.uri = uri
					
				} else {
					
					; No:
					set scraper = ..%New()
					set scraper.name = name
					set scraper.interval = interval
					set (scraper.first, scraper.scraped) = $zdatetime($horolog, 3)
					set scraper.counter = 1
					//set scraper.scraping = stream
					set sc = scraper.scraping.CopyFrom(stream)
					set scraper.uri = uri
					
				}
				
				; Save:
				set sc = scraper.%Save()
				$$$dtThrow(sc, "Failed to save '" _ $get(name) _ "'.")
				
				; Return current scraping:
				set stream = scraper.scraping
				
			} else {
				
				; Previous scraping:
				set:($isobject(scraper)) stream = scraper.scraping _ $char(10) _ $char(10)
				
				; Append the status code and reason:
				do stream.Write("<!-- Status code: " _ http.HttpResponse.StatusCode _ ", Reason: " _ http.HttpResponse.ReasonPhrase _ " -->")
				
			}
			
		} else {
			
			; Current scraping:
			set:($isobject(scraper)) stream = scraper.scraping	
			
		}
		
		; Unescape the HTML:
		set:(stream.Size) return = stream.Read($$$MaxLocalLength)
		
	}
	
	; Return scraping:
	quit return
}

/// <p>
/// Checks if scraping has expired.
/// <br>
/// Boolean return value.
/// </p>
Method expired() As %Boolean
{
	set return = 0
	set:(##this.diff() >= ##this.interval) return = 1
	quit return
}

/// <p>Time difference since last scraping to now in minutes.
/// <br>
/// See <class>%SYSTEM.SQL</class>'s DATEDIFF ClassMethod for more info.
/// </p>
Method diff(datepart As %String = "mi") As %Integer
{
	quit $SYSTEM.SQL.DATEDIFF(datepart, ##this.scraped, $horolog)
}

/// <p>
/// Time since very first scraping.
/// <br>
/// See <class>%SYSTEM.SQL</class>'s DATEDIFF ClassMethod for more info.
/// </p>
Method age(datepart As %String = "mi") As %Integer
{
	quit $SYSTEM.SQL.DATEDIFF(datepart, ##this.first, $horolog)
}

/// <p>Time until next scraping in minutes.</p>
Method next() As %Integer
{
	set return = ##this.interval - ##this.diff()
	set:(return <= 0) return = 0 // We don't want negative numbers.
	quit return
}

/// <p>Elapsed time, in minutes, since last update.</p>
Method elapsed() As %Integer
{
	quit ##this.interval - ##this.next()
}

}
