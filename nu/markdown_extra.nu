; Nu MarkdownExtra
; Copyright (c) 2007 Grayson Hansard
; <http://www.fromconcentratesoftware.com/>
;
; PHP Markdown & Extra
; Copyright (c) 2004-2007 Michel Fortin  
; <http://www.michelf.com/projects/php-markdown/>
;
; Original Markdown
; Copyright (c) 2004-2006 John Gruber  
; <http://daringfireball.net/projects/markdown/>

; March 11, 2008
; Implements header ids.
; Still needs to implement span parsing for table cells
; Also has a bug in which the ending paragraph tag for a definition list may be inserted behind the next element

(load "markdown")

(function markdown_DoHeaders (str)
	(set str (NSMutableString stringWithString:str))
	((/
		(^.+?)								# $1: Header text
		(?:[ ]+\{\#([-_:a-zA-Z0-9]+)\})?	# $2: Id attribute
		[ ]*\n(=+|-+)[ ]*\n+				# $3: Header footer
		/mx findAllInString:str) eachInReverse:(do (m)
			(set level 1)
			(if ((m groupAtIndex:3) hasPrefix:"-") (set level 2))
			(set attrs "")
			(if (m groupAtIndex:2) (set attrs " id=\"#{(m groupAtIndex:2)}\""))
			(str replaceCharactersInRange:(m range) withString:"<h#{level}#{attrs}>#{(markdown_RunSpanGamut (m groupAtIndex:1))}</h#{level}>\n\n")))
	(set hack -"\#") ; Having a literal -"#" in the string makes Nu think that it should be evaluating something.
	(((eregex <<-END
		^(#{hack}{1,6})	# $1 = string of #'s
		[ \t]*
		(.+?)			# $2 = Header text
		[ \t]*
		\#*				# optional closing #'s (not counted)
		(?:[ ]+\{\#([-_:a-zA-Z0-9]+)\})? # $3 id attribute
		[ \t]*
		\n+END "mx") findAllInString:str) eachInReverse:
		(do (m)
			(set attrs "")
			(if (m groupAtIndex:3) (set attrs " id=\"#{(m groupAtIndex:3)}\""))
			(str replaceCharactersInRange:(m range)
				withString:"<h#{((m groupAtIndex:1) length)}#{attrs}>#{(markdown_RunSpanGamut (m groupAtIndex:2))}</h#{((m groupAtIndex:1) length)}>\n\n")))
	str)

(function mdextra_StripFootnotes (str)
	(set str (NSMutableString stringWithString:str))
	
	((/^[ ]{0,4}\[\^(.+?)\][ ]?:	# note_id = $1
			  [ ]*
			  \n?					# maybe *one* newline
			(						# text = $2 (no blank lines allowed)
				(?:					
					.+				# actual text
				|
					\n				# newlines but 
					(?!\[\^.+?\]:\s)# negative lookahead for footnote marker.
					(?!\n+[ ]{0,3}\S)# ensure line is not blank and followed 
									# by non-indented content
				)*
			)/xm findAllInString:str) eachInReverse:(do (m)
			($g_footnotes setObject:(markdown_Outdent (m groupAtIndex:2)) forKey:(m groupAtIndex:1))
			(str replaceCharactersInRange:(m range) withString:"")))
	 (str)
	 )

(function mdextra_StripAbbreviations (str)
	(set str (NSMutableString stringWithString:str))
	((/
		^[ ]{0,4}\*\[(.+?)\][ ]?:	# abbr_id = $1
		(.*)					# text = $2 (no blank lines allowed)	
		/mx findAllInString:str) eachInReverse:(do (m)
			($g_abbr_descriptions setObject:((m groupAtIndex:2) strip) forKey:(m groupAtIndex:1))
			(str replaceCharactersInRange:(m range) withString:"")))
	 (str))

(function mdextra_AppendFootnotes (str)
	(if (!= (($g_footnotes allKeys) count) 0)
		(set tmp (NSMutableString stringWithString:str))
		(tmp appendString:"\n\n<div class=\"footnotes\">\n<hr />\n<ol>\n\n")
		(set num 0)
		(($g_footnotes allKeys) each:(do (k)
			(set num (+ num 1))
			(set footnote ($g_footnotes objectForKey:k))
			(set footnote (mdextra_RunBlockGamut (+ footnote "\n")))
			(set backlink ("<a href=\"#fnref:#{k}\" rev=\"footnote\">&#8617;</a>"))
			(if (/<\/p>$/ findInString:footnote) (set footnote "#{(footnote substringToIndex:(- (footnote length) 4))}&#160;#{backlink}</p>")
			(else (set footnote "#{footnote}\n\n<p>#{backlink}</p>")))
			(tmp appendString:"<li id=\"fn:#{k}\">\n")
			(tmp appendString:footnote)
			(tmp appendString:"\n</li>\n\n")
		
			; Replace an fn link
			(tmp replaceCharactersInRange:(tmp rangeOfString:"!!fn:#{k}!!") withString:"<sup id=\"fnref:#{k}\"><a href=\"#fn:#{k}\" rel=\"footnote\">#{num}</a></sup>")))
		(tmp appendString:"</ol>\n</div>")
		(tmp)
	(else (str))))

(function mdextra_DoTables (str)
	(set str (NSMutableString stringWithString:str))
	((/^							# Start of a line
	[ ]{0,4}	# Allowed whitespace.
	[|]							# Optional leading pipe (present)
	(.+) \n						# $1: Header row (at least one pipe)
	
	[ ]{0,4}	# Allowed whitespace.
	[|] ([ ]*[-:]+[-| :]*) \n	# $2: Header underline
	
	(							# $3: Cells
		(?>
			[ ]*				# Allowed whitespace.
			[|] .* \n			# Row content.
		)*
	)
	(?=\n|\Z)					# Stop at final double newline.
	/mx findAllInString:str) eachInReverse:(do (m)
		(set hed (m groupAtIndex:1))
		(set underline (m groupAtIndex:2))
		(set content (m groupAtIndex:3))
		(set content (/^ *[|]/m replaceWithString:"" inString:content))
		(str replaceCharactersInRange:(m range) withString:(mdextra_DoTableCallback (array (m groupAtIndex:0) hed underline content)))
	))
	 (str))

(function mdextra_DoTableCallback (arr)
	(set hed (arr objectAtIndex:1))
	(set underline (arr objectAtIndex:2))
	(set content (arr objectAtIndex:3))
	
	(set hed (/[|] *$/m replaceWithString:"" inString:hed))
	(set underline (/[|] *$/m replaceWithString:"" inString:underline))
	(set content (/[|] *$/m replaceWithString:"" inString:content))
	
	(set n 0)
	(set attr (dict))
	
	
	(((NuRegex regexWithPattern:" *[|] *") splitString:underline) each: (do (s)
		(if ((/^ *-+: *$/ findAllInString:s) count) (attr setObject:" align=\"right\"" forKey:n)
		(else (if ((/^ *:-+: *$/ findAllInString:s) count) (attr setObject:" align=\"center\"" forKey:n)
		(else (if ((/^ *:-+ *$/ findAllInString:s) count) (attr setObject:" align=\"left\"" forKey:n)
		(else (attr setObject:"" forKey:n)))))))
		(set n (+ n 1))))
	
	; # Parsing span elements, including code spans, character escapes, 
	; # and inline HTML tags, so that pipes inside those gets ignored.
	; $head		= $this->parseSpan($head);
	(set headers ((NuRegex regexWithPattern:" *[|] *") splitString:hed))
	(set col_count (headers count))
	
	(set text (NSMutableString string))
	(text appendString:"<table>\n<thead>\n<tr>\n")
	(set n 0)
	(headers each:(do (header)
		(text appendString:"  <th#{(attr objectForKey:n)}>#{(markdown_RunSpanGamut (header strip))}</th>\n")
		(set n (+ n 1))
	))
	(text appendString:"</tr>\n</thead>\n")
		
	; # Split content by row.
	(set rows ((content chomp) componentsSeparatedByString:"\n"))
	(text appendString:"<tbody>\n")
	(rows each:(do (row)
		; # Parsing span elements, including code spans, character escapes, 
		; # and inline HTML tags, so that pipes inside those gets ignored.
		; $row = $this->parseSpan($row);
		
		; # Split row by cell.
		(set row_cells ((NuRegex regexWithPattern:" *[|] *") splitString:row limit:col_count))
		(set row_cells (mdextra_arraypad row_cells col_count ""))
		(text appendString:"<tr>\n")
		(set n 0)
		(row_cells each:(do (cell)
			(text appendString:"  <td#{(attr objectForKey:n)}>#{(markdown_RunSpanGamut (cell strip))}</td>\n")
			(set n (+ n 1))))
		(text appendString:"</tr>\n")
	))
	(text appendString:"</tbody>\n</table>")
	(+ (mdextra_hashPart text) "\n")
)

(function mdextra_arraypad (arr count pad)
	(set delta (- count (arr count)))
	(if (!= 0 delta) 
		(set arr (NSMutableArray arrayWithArray:arr))
		(delta times:(do (d) (arr addObject:pad))))
	(arr))

(function mdextra_DoDefLists (str)
	(set str (NSMutableString stringWithString:str))
	((/(?:(?<=\n\n)|\A\n?)
	(?>
		(								# $1 = whole list
		  (								# $2
			[ ]{0,4}
			((?>.*\S.*\n)+)				# $3 = defined term
			\n?
			[ ]{0,4}:[ ]+ # colon starting definition
		  )
		  (?s:.+?)
		  (								# $4
			  \z
			|
			  \n{2,}
			  (?=\S)
			  (?!						# Negative lookahead for another term
				[ ]{0,4}
				(?: \S.*\n )+?			# defined term
				\n?
				[ ]{0,4}:[ ]+ # colon starting definition
			  )
			  (?!						# Negative lookahead for another definition
				[ ]{0,4}:[ ]+ # colon starting definition
			  )
		  )
		)
	)/mx findAllInString:str) each:(do (m)
		(set lst (m groupAtIndex:1))
		(set result "<dl>#{(mdextra_ProcessDefListItems lst)}</dl>")
		(set result (mdextra_hashPart ("<dl>\n#{(mdextra_ProcessDefListItems lst)}</dl>" chomp)))
		(str replaceCharactersInRange:(m range) withString:result)
	))
	(str))

(function mdextra_ProcessDefListItems (str)
	(set str (/\n{2,}\z/ replaceWithString:"\n" inString:str))
	; Do DTs
	(set str (NSMutableString stringWithString:str))
	((/(?:\n\n+|\A\n?)					# leading line
	(								# definition terms = $1
		[ ]{0,3}	# leading whitespace
		(?![:][ ]|[ ])				# negative lookahead for a definition 
									#   mark (colon) or more whitespace.
		(?: \S.* \n)+?				# actual term (not whitespace).	
	)			
	(?=\n?[ ]{0,3}:[ ])				# lookahead for following line feed 
									#   with a definition mark.
		/mx findAllInString:str) eachInReverse:(do (m)
			(set terms (((m groupAtIndex:1) chomp) componentsSeparatedByString:"\n"))
			(set txt (NSMutableString string))
			(terms each:(do (term) (txt appendString:"\n<dt>#{(markdown_RunSpanGamut term)}</dt>")))
			(txt appendString:"\n")
			(str replaceCharactersInRange:(m range) withString:txt)))
	;; Do DDs
	((/	\n(\n+)?						# leading line = $1
		[ ]{0,4}		# whitespace before colon
		[:][ ]+							# definition mark (colon)
		((?s:.+?))						# definition text = $2
		(?= \n+ 						# stop at next definition mark,
			(?:							# next term or end of text
				[ ]{0,4} [:][ ]	|
				<dt> | \z
			)						
		)/mx findAllInString:str) eachInReverse:(do (m)
			(set leading_line (m groupAtIndex:1))
			(set deff (m groupAtIndex:2))
			(if (or (leading_line) (/\n{2,}/ findInString:deff))
				(set deff "#{(markdown_outdent (mdextra_RunBlockGamut deff))}")
			else (set deff (markdown_runSpanGamut (markdown_outdent (deff chomp)))))
			(str replaceCharactersInRange:(m range) withString:"\n<dd>#{deff}</dd>\n")
	))
	(str)
)

(function mdextra_DoFootnotes (str)
	(set str (NSMutableString stringWithString:str))
	((/\[\^(.+?)\]/ findAllInString:str) eachInReverse:(do (m)
		(str replaceCharactersInRange:(m range) withString:"!!fn:#{(m groupAtIndex:1)}!!")))
	(str)
)

(function mdextra_DoAbbreviations (str)
	(set str (NSMutableString stringWithString:str))
	(($g_abbr_descriptions allKeys) each:(do (key)
		(set desc ($g_abbr_descriptions objectForKey:key))
		(((NuRegex regexWithPattern:"\\b#{key}\\b") findAllInString:(str)) each:(do (m)
			(if (desc) (str replaceCharactersInRange:(m range) withString:(mdextra_hashPart "<abbr title=\"#{desc}\">#{key}</abbr>"))
			(else (str replaceCharactersInRange:(m range) withString:(mdextra_hashPart "<abbr>#{key}</abbr>"))))
		))
	))
	(str)
)

(function mdextra_hashPart (str)
	(set hash "!!#{(str hash)}!!")
	($g_html_blocks setObject:str forKey:hash)
	hash)
	
(function mdextra_unhash (str)
	(set str (NSMutableString stringWithString:str))
	(($g_html_blocks allKeys) eachInReverse:(do (key)
		(set r (str rangeOfString:key))
		(if (!= (eval (tail r)) 0) (str replaceCharactersInRange:r withString:($g_html_blocks objectForKey:key)))
	))
	(str))

(function markdown_RunSpanGamut (str)
	(set str (markdown_DoCodeSpans str))
	(set str (markdown_EscapeSpecialChars str))
	(set str (mdextra_DoFootnotes str))
	(set str (markdown_DoImages str))
	(set str (markdown_DoAnchors str))
	(set str (markdown_DoAutoLinks str))
	(set str (markdown_EncodeAmpsAndAngles str))
	(set str (markdown_DoItalicsAndBold str))
	(set str ((regex -" {2,}\n") replaceWithString:"<br />\n" inString:str)) ; Do hard breaks
	(set str (mdextra_DoAbbreviations str))
	str)


(function mdextra_RunBlockGamut (str)
	(set str (markdown_DoHeaders str))
	(set str (mdextra_DoTables str))
	(set str (/^[ ]{0,2}([ ]?(\*| [-_])[ ]?){3,}[ \t]*$/mx replaceWithString:"\n<hr />\n" inString:str)); Do horizontal rules
	(set str (markdown_DoLists str))
	(set str (markdown_DoCodeBlocks str))
	(set str (mdextra_DoDefLists str))
	(set str (markdown_DoBlockQuotes str))
	; We already ran _HashHTMLBlocks() before, in Markdown(), but that
	; was to escape raw HTML in the original Markdown source. This time,
	; we're escaping the markup we've just created, so that we don't wrap
	; <p> tags around block-level tags.
	(set str (markdown_HashHTMLBlocks str))
	(set str (markdown_FormParagraphs str))
	(str))

(function mdextra_RunDocumentGamut (str)
	(set str (mdextra_StripFootnotes str))
	(set str (markdown_StripLinkDefinitions str))
	(set str (mdextra_StripAbbreviations str))
	(set str (mdextra_RunBlockGamut str))
	(set str (mdextra_AppendFootnotes str))
	(set str (mdextra_unhash str))
	(str))

(function Markdown (str)
	(set $g_urls (dict))
	(set $g_titles (dict))
	(set $g_html_blocks (dict))
	(set $g_escape_table (dict))
	(set $g_footnotes (dict))
	(set $g_abbr_descriptions (dict))
	(-"\`*_{}[]()>#+-.!" each: (do (c) ($g_escape_table setObject:"!!#{(c hash)}!!" forKey:c)))
	(set $g_nested_brackets -"(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[(?>[^\[\]]+|\[\])*\])*\])*\])*\])*\])*")
	;; From running from Markdown.php
	(set $g_list_level 0)
	;; Standardize line endings
	(set str (/\r\n/ replaceWithString:"\n" inString:str)) ; Convert DOS to Unix
	(set str (/\r/ replaceWithString:"\n" inString:str)) ; Convert Mac to Unix
	;; Make sure text ends with a couple of newlines
	(str appendString:"\n\n")
	;; Convert tabs into 4 spaces
	(set str (markdown_Detab str))
	;; Strip any lines consisting only of spaces and tabs.
	(set str (/^[ \t]+$/m replaceWithString:"" inString:str))
	;; Turn block-level HTML blocks into hash entries
	(set str (markdown_HashHTMLBlocks str))
	;; Strip link definitions, store in hashes.
	(set str (mdextra_RunDocumentGamut str))
	(set str (markdown_UnescapeSpecialChars str))
	(str appendCharacter:'\n')
	str)
