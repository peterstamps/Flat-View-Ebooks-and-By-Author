Last updated: 2015-04-06 time 21:11 CET


VALID LICENSE FOR THIS PLUGIN IS AGPL Version 3.0

This KOreader plugin organizes ALL your eBooks of type epub, pdf, awz3, mobi, docx into Collection(s).
Many people asked for such solution on Reddit and other forums.

The following functions/choices are possible and Optional.

For All functions (1,2 and 3): First set your Home folder under the + Menu or by long tapping on a Folder!  Otherwise the runtime folder (.) will be used!! 

1. One single collection (flat view) with All eBooks. 
   See below Note B.
   More than 10.000 ebooks are created very fast in just a few seconds. After a restart of KOReader the Collection 'All eBooks' becomes visible. 

The choices 2 and 3 may result in many collections and may take quite some time if you have large collections (rule of thumb >500 ebooks)

2. Create by Author a Collection based on meta data. 
   All available books of the same Author(s) on your ereader will be stored in a single collection. 
   The Author name will be based on Metadata details taken from the document when available else the Author name is taken from the file name (see below Note A).

3. Create by Author a Collection based on file name. 
   All available books of the same Author(s) on your ereader will be stored in a single collection. 
   The Author name will only be taken from the file name (see below Note A). If you have used Calibre to save all your ebooks on the ereader and you have standardized/cleaned the Author names with Calibre then THIS choice is preferred above choice 2. 

4. Remove All Collections except Favorites
  Be carefull to use this function. ONLY Favorites will not be deleted and the content will stay as is. If you have manually created your own Collections and you want to keep them dan NEVER use this function as they will be removed!
  If you have only Favorites or some small easy to recreate Collections, then you can use this function and recreate the Collections with the choices 1, 2, 3 shown above.

When using choices 2 AND 3 then one collection PER Author(s names) will be created, same for unique book. However if their are different spellings used for Authors (also between the filename and in the metadata) then ofcourse more collections for the same Author will appear.
So "A.L. Arlige" is NOT the same as "A.L.Arlige" and two collections will appear. That is also the case in Calibre and most eBook software.

NOTE A: 
The default Calibre file name layout in the example below forms the basis for writing the program code for Author extraction:
  EXAMPLE:
  The default Calibre full filenames looks like this: "/Calibre Library Kobo - Test/John Doe/The Mysteries (21)/The Mysteries - John Doe.epub"
  The Author will be taken from the last part of the full filename, here: "The Mysteries - John Doe.epub" 
  The part between the hyphen with space(s) and the file extention is considered to be the Author name, here: "John Doe". That will become the collection name!
  If your eBook file names look like this "John Doe - The Mysteries.epub" or "John Doe - The Mysteries (21).epub" then you will get as Collection "The Mysteries"


NOTE B. ONLY for 'All eBooks' the Collection works independent on how you have organized the structure (all books in one folder so similar like the structure that Calibre by default creates on your reader).



All Collections work as normal KOReader Collections.
You can click on the 'hamburger - or three horizontal stripes at left upper corner' menu in the collection view to sort the collection list.


Under menu Library (cabinet icon) > Click on Create Collections
This will start the Submenu (Choice 1,2,3 and 4 see above).

Fuctions can be coupled to a gesture that you like. 

I use swipe-up movement on right edge of my reader screen and that starts the creation of the 'All eBooks' collection. 
I use swipe-down movement on right edge of my reader screen and that opens the list with collections. 

Always restart KOreader after a new creation process to make the collection(s) and its changes visible.
You can repeat this function without any problem.  



HOW TO USE GESTURES (> means click)
Menu Settings (wheel icon) > Taps and gestures > Gesture manager > One finger swipe > Right Edge Up > General > Page 2 (scroll) > CreateAllMyBooks Collection

HOW TO INSTALL
Copy the folder AllMyeBooks.koplugin  under KOreaders plugin folder (search where KOreader is installed)
Unzip when needed if downloaded as zip file 

AllMyeBooks.koplugin folder looks like:

AllMyeBooks.koplugin
 - main lua
 - _meta.lua
 - readme.md (this file)
 - LICENCE AGPL 3.0.txt
 - Screen prints 

Have FUN.

PS: I used inspiration from a similar solution that was created as a patch but that was always using Favorites and it had severe issues with large collections..only a few hundred books otherwise it crashed. Only epub and pdf were processed.
If you have other types like .txt that you want to make visible look into the source code and and that looks "similar" like this:

    local pfile = popen('find "'..directory..'" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.docx"  | sort ')   
    
  So if you want .txt then it will look like this  
    
        local pfile = popen('find "'..directory..'" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.DOCX" -o -name "*.txt" | sort ')   
        
Note: I have tested it on Ubuntu KOreader version 24.11. 

I expect it will also work on Kobo as I use standard functions of KOreader. 
You might need to set the HOME folder is previous older PLUGIN versions to avoid issues!

The original PLUGIN with only the function 1 above is still available.

