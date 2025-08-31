-- KOReader plugin to add all ebooks found on device to separate collections by author
require "defaults"
package.path = "common/?.lua;frontend/?.lua;" .. package.path
package.cpath = "common/?.so;common/?.dll;/usr/lib/lua/?.so;" .. package.cpath

local Dispatcher = require("dispatcher")  -- luacheck:ignore
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local LuaSettings = require("luasettings")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local DataStorage = require("datastorage")
local ReadCollection = require("readcollection")
local FileManagerCollection = require("apps/filemanager/filemanagercollection")
local Bookinfo = require("apps/filemanager/filemanagerbookinfo")
local DocumentRegistry = require("document/documentregistry")
local DocSettings = require("docsettings")

if G_reader_settings == nil then
    G_reader_settings = require("luasettings"):open(
        DataStorage:getDataDir().."/settings.reader.lua")
end

-- Get the base ebooks folder on the ereader to start the search for ebooks
local ebooks_directory_path = G_reader_settings:readSetting("home_dir")

-- Get the Koreader base folder on the ereader where the settings are stored
local koreader_settings_directory_path = DataStorage:getFullDataDir()

-- Get the Koreader file on the ereader where the settings are stored for collections
local collection_file = DataStorage:getSettingsDir() .. "/collection.lua"

local ReadCollection = {
    coll = nil, -- hash table
    coll_settings = nil, -- hash table
    last_read_time = 0,
    default_collection_name = "favorites",
}

-- read, write

local function buildEntry(file, order, attr)
    file = ffiUtil.realpath(file)
    if file then
        attr = attr or lfs.attributes(file)
        if attr and attr.mode == "file" then
            return {
                file  = file,
                text  = file:gsub(".*/", ""),
                order = order,
                attr  = attr,
            }
        end
    end
end

function ReadCollection:_read()
    --local collection_file_modification_time = lfs.attributes(collection_file, "modification")
    --if collection_file_modification_time then
    --    if collection_file_modification_time <= self.last_read_time then return end
    --    self.last_read_time = collection_file_modification_time
    --end
    local collections = LuaSettings:open(collection_file)
    if collections:hasNot(self.default_collection_name) then
        collections:saveSetting(self.default_collection_name, {})
    end
    logger.dbg("ReadCollection: reading from collection file")
    self.coll = {}
    self.coll_settings = {}
    for coll_name, collection in pairs(collections.data) do
        local coll = {}
        for _, v in ipairs(collection) do
            local item = buildEntry(v.file, v.order)
            if item then -- exclude deleted files
                coll[item.file] = item
            end
        end
        self.coll[coll_name] = coll
        self.coll_settings[coll_name] = collection.settings or { order = 1 } -- favorites, first run
    end
end

function ReadCollection:write(updated_collections)
    local collections = LuaSettings:open(collection_file)
    for coll_name in pairs(collections.data) do
        if not self.coll[coll_name] then
           collections:delSetting(coll_name)
        end
    end
    for coll_name, coll in pairs(self.coll) do
        if updated_collections == nil or updated_collections[1] or updated_collections[coll_name] then
            local is_manual_collate = not self.coll_settings[coll_name].collate or nil
            local data = { settings = self.coll_settings[coll_name] }
            for _, item in pairs(coll) do
                table.insert(data, { file = item.file, order = is_manual_collate and item.order })
            end
            collections:saveSetting(coll_name, data)
        end
    end
    logger.dbg("ReadCollection: writing to collection file")
    collections:flush()
 
end

-- info

function ReadCollection:isFileInCollection(file, collection_name)
    file = ffiUtil.realpath(file) or file
    return self.coll[collection_name][file] and true or false
end

function ReadCollection:getCollectionNextOrder(collection_name)
    if self.coll_settings[collection_name].collate then return end
    local max_order = 0
    for _, item in pairs(self.coll[collection_name]) do
        if max_order < item.order then
            max_order = item.order
        end
    end
    return max_order + 1
end

-- manage items

function ReadCollection:addItem(file, collection_name)
    local item = buildEntry(file, self:getCollectionNextOrder(collection_name))
    self.coll[collection_name][item.file] = item
end

-- manage collections

function ReadCollection:addCollection(coll_name)
    local max_order = 0
    for _, settings in pairs(self.coll_settings) do
        if max_order < settings.order then
            max_order = settings.order
        end
    end
    self.coll_settings[coll_name] = { order = max_order + 1 }
    self.coll[coll_name] = {}
end

-- Extract author name from metadata or file name
local function extractAuthor(collection_type, file_path)
    if not collection_type == "Author Filename" then
      if DocSettings:hasSidecarFile(file_path) then
          local doc_settings = DocSettings:open(file_path)
          if not book_props then
              -- Files opened after 20170701 have a "doc_props" setting with
              -- complete metadata and "doc_pages" with accurate nb of pages
              book_props = doc_settings:readSetting("doc_props")
          end
          if not book_props then
              -- File last opened before 20170701 may have a "stats" setting.
              -- with partial metadata, or empty metadata if statistics plugin
              -- was not enabled when book was read (we can guess that from
              -- the fact that stats.page = 0)
              local stats = doc_settings:readSetting("stats")
              if stats and stats.pages ~= 0 then
                  -- title, authors, series, series_index, language
                  book_props = Document:getProps(stats)
              end
          end
          -- Files opened after 20170701 have an accurate "doc_pages" setting.
          local doc_pages = doc_settings:readSetting("doc_pages")
          if doc_pages and book_props then
              book_props.pages = doc_pages
          end
      end
    end

    -- If still no book_props (book never opened or empty "stats"),
    -- but custom metadata exists, it has a copy of original doc_props
    if not book_props then
        local custom_metadata_file = DocSettings:findCustomMetadataFile(file_path)
        if custom_metadata_file then
            book_props = DocSettings.openSettingsFile(custom_metadata_file):readSetting("doc_props")
        end
    end

    -- Try to get author from metadata
    local document = DocumentRegistry:openDocument(file_path)
    if document then
        local loaded = true
        local pages = nil
         if document.loadDocument then -- CreDocument
            if not document:loadDocument(false) then -- load only metadata
                -- failed loading, calling other methods would segfault
                loaded = false
            end
        end
       
        if loaded then
            local metadata = document:getProps()
            if metadata and metadata.authors then
                document:close()
                --print ("authors: " .. metadata.authors .. ", title: " .. metadata.title)
                -- trim leading and training spaces
                return metadata.authors, metadata.title
            end
            document:close()
        end
      end

    -- Fallback to extracting author from file name
    -- local file_name = file_path:match(".*/([^/]+)$") -- Extract file name from path
    local file_name, extension = file_path:match("^.+/(.+)%.(.+)$") -- Extract file name without extension from path
    if file_name then
        local title, author = file_name:match("^(.+)%s+%-%s+(.-)$") -- Split by " - " 
        --print("title: ", title, "author: ", author, "extension", extension)
        if author then
            return author:gsub("%s+%((.-)$", "") -- Trim trailing spaces
        end
    end
    return "Unknown Author" -- Default if format is not matched
end

local AllMyeBooks = WidgetContainer:extend{
    name = "All eBooks",
    is_doc_only = false,
}

function start(collection_type, ebooks_directory_path)
    UIManager:show(InfoMessage:new{
        text = _("Creating collection(s)... Please wait."),
        timeout=5,
    })
    local files = scandir(ebooks_directory_path)
    ReadCollection:_read()
    
    if collection_type == "All eBooks" then
      local collection_name = "All eBooks"
       ReadCollection:addCollection(collection_name)
      if #files > 0 then
         add_ebooks_to_collection(files, collection_name)
      end  
    else 
      -- Group files by author
      local books_by_author = {}
      for _, file in ipairs(files) do
          local author, title = extractAuthor(collection_type, file)
          if not books_by_author[author] then
              books_by_author[author] = {}
          end
          table.insert(books_by_author[author], file)
      end
      
      -- Sort authors alphabetically
      local sorted_authors = {}
      for author in pairs(books_by_author) do
          table.insert(sorted_authors, author)
      end
      table.sort(sorted_authors, function(a, b) return a < b end)
      
      -- Create a collection for each author and add their books
      for _, author in ipairs(sorted_authors) do
          local collection_name = author
          ReadCollection:addCollection(collection_name)
          add_ebooks_to_collection(books_by_author[author], collection_name)
      end
    end

end

function isAnyPartHidden(path)
    -- Split the path into components (directories and filenames)
    for part in path:gmatch("[^/\\]+") do
        -- Check if any part starts with a dot (hidden file/folder)
        if part:sub(1, 1) == "." then
            return true  -- Found a hidden part in the path
        end
    end
    return false  -- No hidden parts in the path
end


function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('find "'..directory..'" -maxdepth 10 -type f  -name "*.epub" -o -name "*.pdf" -o -name "*.azw3" -o -name "*.mobi" -o -name "*.docx" -o -name "*.cbz" ! -name "*.opf" ! -name "*.jpg" ! -name "*.gz" ! -name "*.zip" ! -name "*.tar" ') -- on linux
    for filename in pfile:lines() do
      if isAnyPartHidden(filename) then
       -- print(filename .. " has a hidden part.")
      else
       -- print(filename .. " has not a hidden part.")
        i = i + 1
        t[i] = filename 
      end -- prevent showing hidden folders or files in the set Home directory of eReader
 
    end
    pfile:close()
    return t
end

function add_ebooks_to_collection(files, collection_name) 
    for _, file in ipairs(files) do
        ReadCollection:addItem(file, collection_name)   
    end
    ReadCollection:write({collection_name})
end

function AllMyeBooks:onDispatcherRegisterActions()
    Dispatcher:registerAction("AllMyeBooks_action", {category="none", event="AllMyeBooks", title=_("Create Collection 'All eBooks'"), general=true,})
end

function AllMyeBooks:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end


function AllMyeBooks:addToMainMenu(menu_items)
    menu_items.AllMyeBooks = {
        text = _("Create Collections"),
        sorting_hint = "filemanager_settings",        
        sub_item_table = {
            {   text = _("Create collection 'All eBooks'"),
                keep_menu_open = false,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("Creating one collection named 'All eBooks'... Please wait."),
                        timeout=5,
                    })
                    start('All eBooks', ebooks_directory_path)                  
                    UIManager:show(InfoMessage:new{
                        text = _("Collection 'All eBooks' has been created. Please restart KOReader for changes to take effect."),
                        timeout=7,
                    })
                end,
            },
            {
                text = _("By Author from Metadata (May take long!)"),
                keep_menu_open = false,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("Creating collections named by Author based on Metadata... Please wait."),
                        timeout=5,
                    })
                    start('Author Metadata', ebooks_directory_path)
                    UIManager:show(InfoMessage:new{
                        text = _("Collections named by Author based on Metadata have been created. Please restart KOReader for changes to take effect."),
                        timeout=7,
                    })
                end,
            },
            {
                text = _("By Author from Filename (May take long!)"),
                keep_menu_open = false,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("Creating collections named by Author based on Filename... Please wait."),
                        timeout=5,
                    })
                    start('Author Filename', ebooks_directory_path)
                    UIManager:show(InfoMessage:new{
                        text = _("Collections named by Author based on Filename have been created. Please restart KOReader for changes to take effect."),
                        timeout=5,
                    })
                end,
            },
            {
                text = _("Remove all Collections except Favorites"),
                keep_menu_open = false,
                callback = function()
                    -- Remove ALL Collections except favorites
                    local collections = LuaSettings:open(collection_file)
                    for coll_name, collection in pairs(collections.data) do
                      -- print ("coll_name, collection:", coll_name, collection)
                      if coll_name == "favorites" then
                          logger.dbg("Remove all Collections except Favorites")
                        else
                          local coll = {}
                          for _, v in ipairs(collection) do
                              local item = nil
                              if item then 
                                  coll_order[coll_name] = nil
                                  coll[item.file] = item
                              end
                          end
                          collections:saveSetting(coll_name, data)           
                      end                     
                    end
                    collections:flush()
                    UIManager:show(InfoMessage:new{
                        text = _("All Collections removed except Favorites. Please restart KOReader for changes to take effect."),
                        timeout=5,
                    })
                end,
            },            
        }
    }

end

function AllMyeBooks:onAllMyeBooks()
    local popup = InfoMessage:new{
      text = _("Creating Collection 'All eBooks'"),
      timeout=5,
    }
    UIManager:show(popup)
    start('All eBooks', ebooks_directory_path)
    local popup = InfoMessage:new{
      text = _("Collection 'All eBooks' has been created. Please restart KOReader for changes to take effect."),
      timeout=9,
    }
    UIManager:show(popup)
end

return AllMyeBooks

