tell application "Skim"
	set theFile to the file of the front document
	set outText to ""
	set newLine to ASCII character 10
	
	# Get the relevant bibliographic information for the front PDF in Skim
	tell application "BibDesk"
		repeat with currentPub in publications of front document
			if linked file of currentPub is {} then
				set bibFile to 0
			else
				set bibFile to first item of linked file of currentPub
			end if
			if bibFile = theFile then
				set theTitle to the title of currentPub
				if author of currentPub is not {} then
					set theAuthor to last name of item 1 of the author of currentPub
				end if
				set citeKey to the cite key of currentPub
				
				# Do italics for books and quotes for articles
				if the type of currentPub is "book" then
					set docTitle to "### " & theAuthor & " - *" & theTitle & "* ###"
				else
					set docTitle to "### " & theAuthor & " - \"" & theTitle & "\" ###"
				end if
				
				
				# This used the commandline tool pdftk to figure out where the table of
				# contents breaks are in the PDF (if they exist).  The typical way to handle
				# this in a PDF is with bookmarks.  We will then iterate over the PDF pages
				# section by section, putting the notes under the appropriate headers.
				set posixFile to POSIX path of theFile
				set sectionTitles to paragraphs of (do shell script "/usr/local/bin/pdftk " & quoted form of posixFile & " dump_data output - | grep 'BookmarkTitle' | sed 's/BookmarkTitle: //g'")
				set sectionPageNumbers to paragraphs of (do shell script "/usr/local/bin/pdftk " & quoted form of posixFile & " dump_data output - | grep 'BookmarkPageNumber' | sed 's/BookmarkPageNumber: //g'")
				set totalPages to do shell script "/usr/local/bin/pdftk " & quoted form of posixFile & " dump_data output - | grep 'NumberOfPages' | sed 's/NumberOfPages: //g'"
				set totalPages to totalPages as integer
				
				
				
				tell application "Skim"
					open theFile
					
					# Do this if the above pdftk bit didn't find any bookmarks in the PDF
					if sectionTitles is {} then
						set notesTogether to ""
						repeat with currentNote in notes of the front document
							set pageLabel to the label of the page of currentNote
							set pageIndex to the index of the page of the currentNote
							set noteFooter to "[Page " & pageLabel & "](sk://" & citeKey & "#" & pageIndex & ")"
							
							# The color test makes it so that my "teaching" notes (which are brown)
							# are filtered out to capture all anchored notes, delete the right conjunct.
							if (type of currentNote is text note) and (color of currentNote is not {44161, 30873, 1586, 65535}) then
								set noteText to the text of currentNote
								set notesTogether to notesTogether & noteText & "   " & newLine & noteFooter & newLine & newLine
							else if (type of currentNote is anchored note) and (color of currentNote is not {44161, 30873, 1586, 65535}) then
								if the text of currentNote is not "" then
									set noteTitle to "#### " & the text of currentNote & " ####" & newLine & newLine
								else
									set noteTitle to ""
								end if
								set noteText to the extended text of currentNote
								set notesTogether to notesTogether & noteTitle & noteText & "   " & newLine & noteFooter & newLine & newLine
							end if
						end repeat
						
						# String all the output together
						if notesTogether is not equal to "" then
							set outText to outText & docTitle & newLine & newLine
							set outText to outText & notesTogether
						end if
						
						# Do this if the above pdftk bit found bookmarks (i.e. a TOC)
						# This iterates over each section.
					else
						set allNotesTogether to ""
						set n to 0
						repeat with currentTitle in sectionTitles
							# Make those bookmarks (TOC) into third level headers
							set currentTitle to "### " & currentTitle & " ###"
							
							set n to n + 1
							set startPage to item n of sectionPageNumbers as integer
							
							if n = (number of items in sectionTitles) then
								set endPage to totalPages
							else
								set endPage to (item (n + 1) of sectionPageNumbers as integer) - 1
							end if
							
							if endPage < startPage then
								set endPage to startPage
							end if
							
							# This is the same as the above loop. (Guess I could have done a function.)
							set notesTogether to ""
							
							set theNotes to notes of pages startPage thru endPage of the front document
							repeat with currentPage in theNotes
								repeat with currentNote in currentPage
									
									set pageLabel to the label of the page of currentNote
									set pageIndex to the index of the page of the currentNote
									set noteFooter to "[Page " & pageLabel & "](sk://" & citeKey & "#" & pageIndex & ")"
									
									if (type of currentNote is text note) and (color of currentNote is not {44161, 30873, 1586, 65535}) then
										set noteText to the text of currentNote
										set notesTogether to notesTogether & noteText & "   " & newLine & noteFooter & newLine & newLine
									else if (type of currentNote is anchored note) and (color of currentNote is not {44161, 30873, 1586, 65535}) then
										if the text of currentNote is not "" then
											set noteTitle to "#### " & the text of currentNote & " ####" & newLine & newLine
										else
											set noteTitle to ""
										end if
										set noteText to the extended text of currentNote
										set notesTogether to notesTogether & noteTitle & noteText & "   " & newLine & noteFooter & newLine & newLine
									end if
									
								end repeat
							end repeat
							
							# Strings these notes together with the previous sections.
							if notesTogether is not equal to "" then
								set allNotesTogether to allNotesTogether & currentTitle & newLine & newLine & notesTogether
							end if
							
							
							# String all the output together	
						end repeat
						if allNotesTogether is not equal to "" then
							set outText to outText & docTitle & newLine & newLine
							set outText to outText & allNotesTogether
						end if
					end if
					
				end tell
				
				
			end if
		end repeat
	end tell
	
	
	
end tell

# Finally create a temp file with the output text and open
# that file in Marked.
set thePath to "/tmp/SkimNotes.md"
do shell script "echo " & quoted form of outText & " > " & thePath
do shell script "open -a Marked " & thePath