if not app.isUIAvailable then
    return
end

-- shorthands
local pc = app.pixelColor
local tc = app.theme.color

-- constants
TileSize = 20 -- tile sizes will always be 20 pixels
PreviewSize = 16 -- tile preview sizes will always be 16 pixels
-- script UI variables
Margin = 20
DialogSize = 120
DragOffsetX, DragOffsetY = 0, 0
LastX, LastY = 0, 0
MaxDragOffset = 20
PreviewScale = 2 / 1.5
StartLayer = 1

-- default preview colors
Highlight = Color { r = 200, g = 200, b = 200 }
Unshaded = Color { r = 128, g = 128, b = 128 }
Shaded = Color { r = 50, g = 50, b = 50 }
Background = Color { r = 255, g = 255, b = 255 }

IgnoreChanges = false

---@type SpriteData
ActiveData = nil
---@type Image
PaletteImage = nil
---@type Image
CopyImage = nil

---@class SpriteData
---@field sprite Sprite
---@field size Size
---@field buffer integer
---@field repeatL integer[]
---@field layers integer
---@field random integer
---@field effectColors boolean
---@field previewRandom integer
---@field specs integer[]
---@field specs2 integer[] | nil
---@field tags table
---@field initLine string
data = {}

---@param sprite Sprite
---@return SpriteData | nil
function data:init(sprite)
    if sprite then
        data[sprite.filename] = {
            sprite = sprite,
            size = Size(1, 1),
            buffer = 0,
            repeatL = { 1 },
            layers = 1,
            random = 1,
            effectColors = false,
            previewRandom = 1,
            specs = {},
            specs2 = nil,
            tags = {},
            initLine = ""
        }
        return data[sprite.filename]
    end
    return nil
end
---@param sprite Sprite
---@return SpriteData | nil
function data:getOrCreate(sprite)
    return sprite and data[sprite.filename] or data:init(sprite)
end

---@type Dialog
local set = nil
local lastTab = nil

-- Keep track of user resizing and positioning
local setW = DialogSize * 1.5
local setH = DialogSize * 2
local setX = app.window.width - Margin - setW
local setY = Margin
---@type Dialog
local prv = nil
---@type Dialog | nil
local lyrs = nil
---@type Dialog | nil
local init = nil

-- math
---@return number
---@param x number
---@param y number
---@param a number
function Lerp(x, y, a)
	return x * (1-a) + y*a;
end

---@param x Color
---@param y Color
function LerpCol(x, y, a)
    if not x or not y then
        return Color()
    end
    return Color {
        r = Lerp(x.red, y.red, a),
        g = Lerp(x.green, y.green, a),
        b = Lerp(x.blue, y.blue, a),
    }
end

---@return number
---@param val number
---@param min number
---@param max number
function Clamp(val, min, max)
    return math.max(min, math.min(val, max))
end

---@return Color
---@param p pixelColor
function GetCol(p)
    return Color{ r = pc.rgbaR(p), g = pc.rgbaG(p), b = pc.rgbaB(p), a = pc.rgbaA(p)}
end

---@return Color
---@param x integer
---@param y integer
---@param default Color?
function GetPaletteCol(x, y, default)
    return PaletteImage and GetCol(PaletteImage:getPixel(x, y)) or default
end

---@return Size
---@param scaled boolean
function GetImageSize(scaled)
    if ActiveData then
        local size =  Size((ActiveData.size.w * TileSize) + ((ActiveData.buffer * 2) * TileSize), (ActiveData.size.h * TileSize) + ((ActiveData.buffer * 2) * TileSize))
        if scaled then
            size.w = size.w * PreviewScale
            size.h = size.h * PreviewScale
        end
        return size
    end
    return Size(TileSize * PreviewScale, TileSize * PreviewScale);
end

function CreateCopyImage()
    if ActiveData and ActiveData.sprite then
        -- get sublayers first
        local totalSubLayers = 0
        for l = 1, ActiveData.layers, 1 do
            totalSubLayers = totalSubLayers + (ActiveData.repeatL[l] or 1)
        end
        totalSubLayers = math.min(totalSubLayers, 30)

        local uSize = GetImageSize(false)
        local width, height = ActiveData.sprite.width, ActiveData.sprite.height
        ActiveData.effectColors = false
        local copy = Image(width, height)
        for _, image in ipairs(ActiveData.sprite.layers) do
            local cel = image:cel(1)
            if cel then
                copy:drawImage(cel.image:clone())
            end
        end

        local effectCols, effA, effB = false, false, false
        for it in copy:pixels() do
            local col = GetCol(it())
            local r, g, b = col.red, col.green, col.blue
            if (b > 0 and g > 0 and r == 0)
            or (r > 0 and b > 0 and g == 0) then -- effect colors
                effectCols = true
                effA = effA and effA or (b > 0 and g > 0 and r == 0)
                effB = effB and effB or (r > 0 and b > 0 and g == 0)
                col = Color { r = r, g = g, b = b, a = 255 - pc.rgbaR(copy:getPixel((copy.width / 2) + it.x, it.y)) }
            end
            it(col.rgbaPixel)
        end

        ActiveData.effectColors = effectCols
        ActiveData.tags["effectColorA"] = effA
        ActiveData.tags["effectColorB"] = effB

        local cWidth = ActiveData.effectColors and width / 2 or width
        CopyImage = Image(cWidth, uSize.h * totalSubLayers)
        ---@type GraphicsContext
        local gc = CopyImage.context
        -- then process as layers
        local subLayer = 1
        for l = 1, ActiveData.layers, 1 do
            local rep = ActiveData.repeatL[l] or 1 -- Layer repeats
            local sourceRect = Rectangle(0, 1 + (uSize.h * (l - 1)), cWidth, uSize.h)
            for re = 1, rep, 1 do
                if subLayer > 30 then
                    break
                end
                local destRect = Rectangle(0, uSize.h * (subLayer - 1), cWidth, uSize.h)
                gc:drawImage(copy, sourceRect, destRect)
                subLayer = subLayer + 1
            end
        end
        
        local lastLerp = -1
        local h, u, s
        for it in CopyImage:pixels() do
            local lerp = (math.ceil(it.y / uSize.h) + (StartLayer - 1)) / 30
            -- Draw colors
            local x = math.ceil(lerp * 30)
            local fade = lerp * 0.5
            if lastLerp ~= lerp then
                lastLerp = lerp
                if PaletteImage then
                    h = GetPaletteCol(x, 2)
                    u = GetPaletteCol(x, 3)
                    s = GetPaletteCol(x, 4)
                else
                    h = LerpCol(Highlight, Background, fade)
                    u = LerpCol(Unshaded, Background, fade)
                    s = LerpCol(Shaded, Background, fade)
                end
            end

            local col = GetCol(it())
            local r, g, b = col.red, col.green, col.blue
            if r > 0 and g > 0 and b > 0 then -- white
                col = Color{a = 0}
            elseif (b > 0 and g > 0 and r == 0)
                or (r > 0 and b > 0 and g == 0) then -- effect colors
            elseif r == 0 and b > 0 then
                col = h
            elseif g > 0 and b == 0 then
                col = u
            elseif r > 0 and b == 0 then
                col = s
            end
            it(col.rgbaPixel)
        end
    end
end

function DrawPreviewSprite(ev)
    ---@type GraphicsContext
    local gc = ev.context
    local size = GetImageSize(true)
    local pos = Point{
        x = ((Margin * 2) * PreviewScale) / 3,
        y = ((Margin * 2) * PreviewScale) / 2.5,
    }
    local background = GetPaletteCol(1, 0, Background)

    -- Set background
    gc:beginPath()
    gc:rect(Rectangle(pos.x - 2, pos.y, size.w, size.h))
    gc.color = background
    gc:fill()
    gc.color = tc.editor_sprite_border
    gc:stroke()

    -- Then shenanijans
    if ActiveData and ActiveData.sprite then
        local uSize = GetImageSize(false)
        if CopyImage then
            -- draw image
            gc.color = background
            local totalSubLayers = 0
            for l = 1, ActiveData.layers, 1 do
                totalSubLayers = totalSubLayers + (ActiveData.repeatL[l] or 1)
            end
            totalSubLayers = math.min(totalSubLayers, 30)
            local subLayer = totalSubLayers
            for l = ActiveData.layers, 1, -1 do
                local rep = ActiveData.repeatL[l] or 1 -- Layer repeats
                for re = rep, 1, -1 do
                    if subLayer + StartLayer > 30 then
                        subLayer = subLayer - 1
                        goto continue
                    end
                    local lerp = subLayer / totalSubLayers
                    local sourceRect = Rectangle(uSize.w * (ActiveData.previewRandom - 1), uSize.h * (subLayer - 1), uSize.w, uSize.h)
                    gc:drawImage(CopyImage, sourceRect, Rectangle(Lerp(pos.x - DragOffsetX, pos.x + DragOffsetX, lerp) - PreviewScale, Lerp(pos.y - DragOffsetY, pos.y + DragOffsetY, lerp), size.w, size.h))
                    subLayer = subLayer - 1
                    ::continue::
                end
            end
        end
    end
end

function RepaintPreview()
    if prv then
        prv:repaint()
    end
end

-- Preview values
local lastMouseX, lastMouseY
local moving = false
local selectingColor = false

function DrawPreview()
    local size = GetImageSize(true)
    if prv then
        prv:close()
    end

    local diaSize = size
    diaSize.w = size.w + (((Margin * 2) + (2 / PreviewScale))  * PreviewScale)
    diaSize.h = size.h + (((Margin * 2) + (18 / PreviewScale)) * PreviewScale)

    prv = Dialog {
            title = "Tile Preview",
            resizeable = false
        }
        :canvas {
            id = "preview",
            onpaint = DrawPreviewSprite,
            width = size.w,
            height = size.h,
            autoscaling = false,
            vexpand=false,
            hexpand=false,
            ---@param ev MouseEvent
            onmousedown = function (ev)
                lastMouseX, lastMouseY = ev.x, ev.y
                LastX, LastY = DragOffsetX, DragOffsetY
                moving = true
            end,
            ---@param ev MouseEvent
            onmousemove = function (ev)
                if lastMouseX and lastMouseY and moving then
                    DragOffsetX = Clamp(LastX + ((lastMouseX - ev.x) / 2), MaxDragOffset * -1, MaxDragOffset)
                    DragOffsetY = Clamp(LastY + (lastMouseY - ev.y) / 2, MaxDragOffset * -1, MaxDragOffset)
                    RepaintPreview()
                end
            end,
            onmouseup = function (ev)
                moving = false
            end,
            onkeydown = function (ev)
                if ev.code == "KeyP" then
                    IgnoreChanges = true
                    app.command.NewFile{
                        ui = false,
                        width = CopyImage.width,
                        height = CopyImage.height,
                    }
                    app.image:drawImage(CopyImage)
                end
            end
        }
        if ActiveData and ActiveData.random > 1 then
            prv:newrow {}
            prv:slider {
                id = "randomSlider",
                min = 1,
                max = ActiveData.random,
                value = ActiveData.previewRandom,
                onchange = function ()
                    ActiveData.previewRandom = prv.data.randomSlider
                    RepaintPreview()
                end
            }
        end
        prv:show {
            wait = false,
            bounds = Rectangle(setX - diaSize.w, setY, diaSize.w, diaSize.h + ((ActiveData and ActiveData.random > 1) and 40 or 0))
        }
        :repaint()
end

-- init editor values
GeoTypes = {
    Empty = -1,
    Air = 0,
    Solid = 1,
    NESlope = 2,
    NWSlope = 3,
    SESlope = 4,
    SWSlope = 5,
    Platform = 6,
    Glass = 9
}
GeoKeys = {
    "Empty",
    "Air",
    "Solid",
    "NESlope",
    "NWSlope",
    "SESlope",
    "SWSlope",
    "Platform",
    "Glass"
}
Geos = #GeoKeys
---@type integer | nil
local hoveredGeo = nil
local selectedGeo = GeoTypes.Empty

-- Tile tags
Tags = {
    "notTrashProp",
    "notProp",
    "nonSolid",
    "drawLast",
    "Big Sign",
    "Small Asian Sign",
    "small asian sign on wall",
    "Big Western Sign",
    "Big Western Sign Tilted",
    "Larger Sign",
    "Big Wheel",
    "fanBlade",
    "harvester",
    "randomCords",
    -- comms exclusive
    "Big Sign B",
    "Big Western Sign B",
    "Big Western Sign Tilted B",
    "Small Asian Sign B",
    "small asian sign on wall B",
    "Small Asian Sign Station",
    "Small Asian Sign On Wall Station",
    "Small Asian Sign Station B",
    "Small Asian Sign On Wall Station B",
    "Larger Sign B",
    "Station Larger Sign",
    "Station Larger Sign B",
    "Station Lamp",
    "LumiaireH",
    "notMegaTrashProp",
    "notTile"
}

local bgCol = tc.background
---@return Color
---@param sel boolean | nil
local function bdCol(sel)
    return not sel and tc.editor_sprite_border or tc.text
end
local geoCol = tc.text

---@param gc GraphicsContext
---@param rect Rectangle
---@param type integer
---@param col Color
---@param isSelected boolean | nil
---@param opacity number | nil
function DrawGeoSquare(gc, rect, type, col, isSelected, opacity)
    if gc then
        local x, y, w, h = rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2
        local smallRect = Rectangle(x, y, w, h)
        gc:save()
        gc.color = bgCol
        if opacity then
            gc.opacity = opacity * 255
        end
        gc:fillRect(rect)
        gc.opacity = 255

        gc.color = col
        if type == GeoTypes.Empty then
            gc:beginPath()
            gc:moveTo(x, y)
            gc:lineTo(x + w, y + h)
            gc:moveTo(x + w, y)
            gc:lineTo(x, y + h)
            gc:stroke()
        elseif type == GeoTypes.Air then
            gc:strokeRect(smallRect)
        elseif type == GeoTypes.Solid then
            gc:fillRect(smallRect)
        elseif type == GeoTypes.NESlope then
            gc:beginPath()
            gc:moveTo(x, y)
            gc:lineTo(x + w, y + h)
            gc:lineTo(x, y + h)
            gc:fill()
        elseif type == GeoTypes.NWSlope then
            gc:beginPath()
            gc:moveTo(x + w, y)
            gc:lineTo(x + w, y + h)
            gc:lineTo(x, y + h)
            gc:fill()
        elseif type == GeoTypes.SESlope then
            gc:beginPath()
            gc:moveTo(x, y)
            gc:lineTo(x + w, y)
            gc:lineTo(x, y + h)
            gc:fill()
        elseif type == GeoTypes.SWSlope then
            gc:beginPath()
            gc:moveTo(x, y)
            gc:lineTo(x + w, y + h)
            gc:lineTo(x + w, y)
            gc:fill()
        elseif type == GeoTypes.Platform then
            gc:beginPath()
            local wid = (h / 8)
            gc:moveTo(x, y + (h / 2) - wid)
            gc:lineTo(x + w, y + (h / 2) - wid)
            gc:lineTo(x + w, y + (h / 2) + wid)
            gc:lineTo(x, y + (h / 2) + wid)
            gc:fill()
            gc:beginPath()
            gc:moveTo(x, y + (h / 2) + wid * 2)
            gc:lineTo(x, y + (h / 2) + wid)
            gc:moveTo(x + w - 1, y + (h / 2) + wid * 2)
            gc:lineTo(x + w - 1, y + (h / 2) + wid)
            gc:stroke()
        elseif type == GeoTypes.Glass then
            gc:strokeRect(smallRect)
            gc:beginPath()
            gc:moveTo(x + (w / 1.5), y)
            gc:lineTo(x, y + (h / 1.5))
            gc:moveTo(x, y + h)
            gc:lineTo(x + w, y)
            gc:stroke()
        end
        gc.color = bdCol(isSelected)
        gc:strokeRect(rect)
        gc:restore()
    end
end

function UpdateInitLine()
    if init and ActiveData and ActiveData.sprite then
        -- create init line
        local s = "[#nm:\"" .. (set and set.data.tileName or app.fs.fileTitle(ActiveData.sprite.filename)) .. "\", "
        s = s .. "#sz:point(" .. tostring(ActiveData.size.w) .. "," .. tostring(ActiveData.size.h) .. "), "

        -- specs
        s = s .. "#specs:["
        for i = 1, #ActiveData.specs, 1 do
            s = s .. tostring(ActiveData.specs[i])
            if i ~= #ActiveData.specs then
                s = s .. ","
            end
        end
        s = s .. "], "

        -- specs2
        s = s .. "#specs2:"
        if ActiveData.specs2 then
            s = s .. "["
            for i = 1, #ActiveData.specs2, 1 do
                s = s .. tostring(ActiveData.specs2[i])
                if i ~= #ActiveData.specs2 then
                    s = s .. ","
                end
            end
            s = s .. "]"
        else
            s = s .. "0"
        end
        s = s .. ", "

        s = s .. "#tp:\"voxelStruct\", "

        -- repeatL
        s = s .. "#repeatL:["
        for i = 1, #ActiveData.repeatL, 1 do
            s = s .. tostring(ActiveData.repeatL[i])
            if i ~= #ActiveData.repeatL then
                s = s .. ","
            end
        end
        s = s .. "], "

        -- buffer
        s = s .. "#bfTiles:" .. tostring(ActiveData.buffer) .. ", "

        -- variations
        s = s .. "#rnd:" .. tostring(ActiveData.random) .. ", "

        s = s .. "#ptPos:0, "

        -- tags
        s = s .. "#tags:["
        local t = {}
        for k, v in pairs(ActiveData.tags) do
            if v then
                t[#t+1] = k
            end
        end
        for i, v in ipairs(t) do
            s = s .. "\"" .. v .. "\""
            if i ~= #t then
                s = s .. ", "
            end
        end
        s = s .. "]]"

        ActiveData.initLine = s
        init:repaint()
    end
end

---@param ev MouseEvent
function UpdateSpecs(ev, tileScale, editingLayer)
    if ActiveData then
        local x = Clamp(math.ceil((ev.x - 30) / tileScale), 1, ActiveData.size.w)
        local y = Clamp(math.ceil(ev.y / tileScale), 1, ActiveData.size.h)
        local index = x + ((y - 1) * ActiveData.size.w)
        if #ActiveData.specs >= index then
            ((ActiveData.specs2 ~= nil and editingLayer == 2) and ActiveData.specs2 or ActiveData.specs)[index] = selectedGeo
            UpdateInitLine()
        end
    end
end

function DrawInitEditor()
    if init then
        init:close()
    end
    if ActiveData then
        local tileScale = 20
        local smallTileScale = tileScale / 1.5
        local newSpecs, newSpecs2 = {}, {}
        for l = 1, ActiveData.size.w * ActiveData.size.h, 1 do
            newSpecs[l] = ActiveData.specs[l] or -1
            if ActiveData.specs2 then
                newSpecs2[l] = ActiveData.specs2[l] or -1
            end
        end
        ActiveData.specs = newSpecs
        if ActiveData.specs2 then
            ActiveData.specs2 = newSpecs2
        end

        local editingLayer = 1

        init = Dialog{
            title = "Init Editor",
            resizeable = false,
            vexpand = false
        }
        :button {
            text = "Copy Init Line",
            onclick = function ()
                if ActiveData then
                    app.clipboard.text = ActiveData.initLine
                    app.alert("Copied text!")
                end
            end
        }
        :newrow()
        :tab {
            text = "Specs Editor"
        }
        :check {
            text = "Use Layer 2",
            selected = ActiveData and ActiveData.specs2,
            onclick = function ()
                if ActiveData then
                    ActiveData.specs2 = ActiveData.specs2 == nil and {} or nil
                    if ActiveData.specs2 then
                        for i = 1, #ActiveData.specs do
                            ActiveData.specs2[i] = -1
                        end
                    end
                    DrawInitEditor()
                end
            end
        }
        :button {
            text = "Switch Layer",
            enabled = ActiveData and ActiveData.specs2 ~= nil,
            onclick = function ()
                editingLayer = editingLayer == 1 and 2 or 1
                if init then
                    init:repaint()
                end
            end
        }
        local w, h = (ActiveData.size.w * tileScale) + 1, (ActiveData.size.h * tileScale) + 1
        init:canvas {
            width = w + 30,
            height = h,
            vexpand = false,
            hexpand = false,
            autoscaling = false,
            onpaint = function (ev)
                ---@type GraphicsContext
                local gc = ev.context

                -- Draw tiles
                if ActiveData then
                    local t = "Lyr " .. tostring(editingLayer)
                    gc.color = tc.text
                    gc:fillText(t, 0, 0)
                    -- Draw base grid
                    for x = 1, ActiveData.size.w, 1 do
                        for y = 1, ActiveData.size.h, 1 do
                            local area = Rectangle(30 + (tileScale * (x - 1)), tileScale * (y - 1), tileScale + 1, tileScale + 1)
                            local index = x + ((y - 1) * ActiveData.size.w)
                            local specs2 = ActiveData.specs2 ~= nil and editingLayer == 2
                            DrawGeoSquare(gc, area, (not specs2 and ActiveData.specs2 or ActiveData.specs)[index], geoCol)
                            DrawGeoSquare(gc, area, (specs2 and ActiveData.specs2 or ActiveData.specs)[index], geoCol, false, 0.7)
                        end
                    end
                end
            end,
            onmousemove = function (ev)
                hoveredGeo = nil
                if init then
                    init:repaint()
                end

                if ev.button ~= 0 then
                    UpdateSpecs(ev, tileScale, editingLayer)
                end
            end,
            onmousedown = function (ev)
                UpdateSpecs(ev, tileScale, editingLayer)
            end
        }
        :canvas {
            width = smallTileScale + 50,
            height = smallTileScale * Geos,
            hexpand = false,
            vexpand=false,
            autoscaling = false,
            onpaint = function (ev)
                ---@type GraphicsContext
                local gc = ev.context
                
                gc.color = bdCol(false)
                gc:fillRect(Rectangle(0, 0, gc.width, gc.height))

                for i, g in ipairs(GeoKeys) do
                    local isSelected = hoveredGeo and GeoTypes[g] == hoveredGeo or GeoTypes[g] == selectedGeo
                    local rect = Rectangle(0, smallTileScale * (i - 1), smallTileScale, smallTileScale)
                    DrawGeoSquare(gc, rect, GeoTypes[g], geoCol, isSelected)
                    
                    -- draw info off to right
                    if isSelected then
                        gc.color = bdCol(isSelected)
                        gc:fillRect(Rectangle(smallTileScale, (i - 1) * smallTileScale, 50, smallTileScale))
                    end
                    gc.color = bdCol(not isSelected)
                    gc:fillText(g, smallTileScale + 1, (smallTileScale * (i - 1)) + (gc:measureText(g).h / 2))
                end
            end,
            onmousemove = function (ev)
                hoveredGeo = Clamp(math.ceil((ev.y - smallTileScale) / smallTileScale), 0, Geos) + 1
                if hoveredGeo > 0 and hoveredGeo <= Geos then
                    hoveredGeo = GeoTypes[GeoKeys[hoveredGeo]]
                else
                    hoveredGeo = nil
                end
                if init then
                    init:repaint()
                end
            end,
            onmousedown = function (ev)
                if hoveredGeo then
                    selectedGeo = hoveredGeo
                    if init then
                        init:repaint()
                    end
                end
            end
        }
        :newrow()
        :tab {
            text = "Tags"
        }
        :button {
            text = "Open Reference Page",
            onclick = function ()
                app.command.Launch { path = "https://rainworldmodding.miraheze.org/wiki/Creating_Custom_Tiles_and_Props#Possible_tile_tags" }
            end
        }
        for i, t in ipairs(Tags) do
            init:check {
                text = t,
                selected = ActiveData.tags[t],
                onclick = function ()
                    if ActiveData then
                        ActiveData.tags[t] = ActiveData.tags[t] and not ActiveData.tags[t] or true
                        UpdateInitLine()
                    end
                end
            }
            init:newrow()
        end
        init:endtabs()
        :show {
            wait = false,
            bounds = Rectangle((app.window.width / 2) - (DialogSize * .85), (app.window.height / 2) - (DialogSize * .85), DialogSize * 1.7, DialogSize * 1.7),
            autoscrollbars = true,
        }
        UpdateInitLine()
    end
end

function DrawLayers()
    if lyrs then
        lyrs:close()
    end
    lyrs = Dialog {
        title = "Repeat Layers Settings",
        resizeable = false,
        onclose = function ()
            lyrs = nil
        end
    }
    :canvas {
        width = 150,
        height = 20,
        autoscaling = true,
        onpaint = function (ev)
            ---@type GraphicsContext
            local gc = ev.context
            local w, h = gc.width - 1, gc.height - 1
            gc.color = Color { r = 100, g = 100, b = 255 }
            gc:rect(Rectangle(0, 0, w, h))
            gc:fill()
            gc.color = app.theme.color.editor_sprite_border
            gc:stroke()
            
            -- layers
            gc.color = Color { r = 100, g = 255, b = 100 }
            gc:fillRect(Rectangle(50, 1, 50, 18))
            gc.color = Color { r = 255, g = 100, b = 100 }
            gc:fillRect(Rectangle(100, 1, 49, 18))

            -- repeat layers
            if ActiveData then
                local x = 0
                for i = 1, ActiveData.layers, 1 do
                    local wL = ActiveData.repeatL[i] * 5
                    local rect = Rectangle(x, 0, wL + 1, 20)
                    local s = tostring(i)
                    gc.color = app.theme.color.background
                    gc.opacity = 128
                    gc:fillRect(rect)
                    gc.opacity = 255
                    gc.color = app.theme.color.editor_sprite_border
                    gc:strokeRect(rect)
                    gc:fillText(s, Lerp(x, x + wL + 1, 0.5) - (gc:measureText(s).w / 2), 7)
                    x = x + wL
                end
            end
        end
    }
    if ActiveData then
       for i = 1, ActiveData.layers, 1 do
        local iString = tostring(i)
            lyrs:number {
                id = iString,
                label = "Layer " .. iString,
                text = tostring(ActiveData.repeatL[i]),
                decimals = 0,
                onchange = function ()
                    ActiveData.repeatL[i] = tonumber(lyrs.data[iString])
                    CreateCopyImage()
                    RepaintPreview()
                    lyrs:repaint()
                    UpdateInitLine()
                end
            }
       end
    end
    lyrs:show {
        wait = false,
        bounds = Rectangle(app.window.width / 2, app.window.height / 2, DialogSize, 0)
    }
end

function DrawSettings()
    -- Show grid
    local prefs = app.preferences.document(app.sprite)
    prefs.grid.bounds = Rectangle {
        x = 0,
        y = 1,
        width = TileSize,
        height = TileSize
    }
    if app.sprite and app.sprite.colorMode ~= ColorMode.RGB then
        app.transaction("Change Sprite Settings", function ()
            app.sprite.gridBounds = prefs.grid.bounds
            app.command.ChangePixelFormat{ ui=false, format="rgb" }
            if ActiveData then
                ActiveData.sprite = app.sprite
            end
        end)
    end

    -- Draw dialog
    if set then
        setX = set.bounds.x
        setY = set.bounds.y
        lastTab = set.data.tabs
        set:close()
    end

    -- if attachedImage then
    --     layers = math.floor((attachedImage.height - 1) / height)
    -- end
    set = Dialog {
            title = "RW Tile Previewer",
            autofit = Align.TOP,
            resizeable = false
        }
        -- Tile settings
        :tab { id = "settings", text = "Tile Settings" }
        :label { text = "VoxelStruct Setting"}
        :newrow { }
        :entry {
            id = "tileName",
            label = "Name",
            text = app.sprite and app.fs.fileTitle(app.sprite.filename) or "",
            onchange = function ()
                if set then
                    ActiveData.sprite.filename = set.data.tileName
                end
                UpdateInitLine()
            end
        }
        :number {
            id = "sizeX",
            label = "Size",
            text = tostring(ActiveData and ActiveData.size.w or 1),
            decimal = 0,
            onchange = function ()
                if ActiveData then
                    ActiveData.size.w = set.data.sizeX
                    CreateCopyImage()
                    DrawSettings()
                    if init then
                        DrawInitEditor()
                    end
                end
            end
        }
        :number {
            id = "sizeY",
            text = tostring(ActiveData and ActiveData.size.h or 1),
            decimal = 0,
            onchange = function ()
                if ActiveData then
                    ActiveData.size.h = set.data.sizeY
                    CreateCopyImage()
                    DrawSettings()
                    if init then
                        DrawInitEditor()
                    end
                end
            end
        }
        :number {
            id = "layers",
            label = "Layers",
            text = tostring(ActiveData and ActiveData.layers or 1),
            decimal = 0,
            onchange = function ()
                if ActiveData then
                    ActiveData.layers = set.data.layers
                    local newRepeatL = {}
                    for i = 1, ActiveData.layers, 1 do
                        newRepeatL[i] = ActiveData.repeatL[i] or 1
                    end
                    ActiveData.repeatL = newRepeatL
                    CreateCopyImage()
                    DrawSettings()
                    if lyrs then
                        DrawLayers()
                    end
                    UpdateInitLine()
                end
            end
        }
        :button {
            text = "Repeat Layers",
            onclick = DrawLayers
        }
        :number {
            id = "buffer",
            label = "Buffer",
            text = tostring(ActiveData and ActiveData.buffer or 0),
            decimal = 0,
            onchange = function ()
                if ActiveData then
                    ActiveData.buffer = set.data.buffer
                    CreateCopyImage()
                    DrawSettings()
                end
            end
        }
        :number {
            id = "random",
            label = "Variations",
            text = tostring(ActiveData and ActiveData.random or 1),
            decimal = 0,
            onchange = function ()
                if ActiveData then
                    ActiveData.random = set.data.random
                    ActiveData.previewRandom = Clamp(ActiveData.previewRandom, 1, ActiveData.random)
                    DrawSettings()
                end
            end
        }

    -- Checks for image dimensions
    local l = ActiveData and ActiveData.layers or 1
    local size = ActiveData and ActiveData.size or Size(1, 1)
    local effCol = (ActiveData and ActiveData.effectColors) and 2 or 1
    local rnd = ActiveData and ActiveData.random or 1
    local buffer = ActiveData and ActiveData.buffer or 0
    local pixelSize = Size{
        w = ((size.w + (buffer * 2)) * TileSize) * effCol * rnd,
        h = ((size.h + (buffer * 2)) * TileSize * l) + (size.h * PreviewSize) + 1
    }
    set:label {
        label = "Dimensions",
        text = tostring(pixelSize.w)
        .." x "
        ..tostring(pixelSize.h)
    }
    if ActiveData and ActiveData.sprite then
        local sprite = ActiveData.sprite
        set:button {
            text = "Correct Size",
            enabled = sprite.width ~= pixelSize.w or sprite.height ~= pixelSize.h,
            onclick = function ()
                app.command.CanvasSize{
                    ui = false,
                    right = pixelSize.w - sprite.width,
                    bottom = pixelSize.h - sprite.height
                }
            end
        }
    end
    set:newrow()
    set:button {
        text = "Init Editor",
        onclick = DrawInitEditor
    }
        :newrow {}
        -- Helpful shortcuts
    set:tab { id = "tools", text = "Tools" }
        :label { text = "VoxelStruct Colors" }
        :newrow()
        :label { text = "Highlight"}
        :label { text = "Unshaded"}
        :label { text = "Shadow"}
        :newrow()
        :shades {
            mode = "pick",
            colors = {
                Color { r = 0, g = 0, b = 255 },
                Color { r = 0, g = 255, b = 0 },
                Color { r = 255, g = 0, b = 0 },
            },
            onclick = function (ev)
                app.fgColor = ev.color
            end
        }
        :separator()
        :label { text = "Effect Colors A / B"}
        :newrow()
        :shades {
            colors = {
                Color { r = 255, g = 0, b = 255 },
                Color { r = 0, g = 255, b = 255 }
            },
            onclick = function (ev)
                app.fgColor = ev.color
            end
        }
        :newrow()
        :label { text = "Effect Color Alpha" }
        :newrow()
        :canvas {
            width = DialogSize,
            height = 23,
            onpaint = function (ev)
                -- draw selector box
                ---@type GraphicsContext
                local gc = ev.context
                for i = 1, gc.width, 1 do
                    local c = Clamp(i * (255 / gc.width), 0, 255)
                    gc.color = Color { r = c, g = c, b = c }
                    gc:fillRect(Rectangle(i, 10, 1, 13))
                end
                gc.color = tc.text
                gc:fillText("100%", 0, 0)
                local m = "50%"
                gc:fillText(m, (gc.width / 2) - (gc:measureText(m).w / 2), 0)
                local t = "0%"
                gc:fillText(t, gc.width - gc:measureText(t).w, 0)
                gc.color = tc.editor_sprite_border
                gc:strokeRect(Rectangle(0, 10, 255, 13))
                gc:strokeRect(Rectangle(gc.width / 2, 10, 1, 13))
            end,
            onmousedown = function (ev)
                selectingColor = true
                local c = Clamp((ev.x / (setW - Margin)) * 255, 0, 255)
                app.fgColor = Color { r = c, g = c, b = c }
            end,
            onmousemove = function (ev)
                if selectingColor then
                    local c = Clamp((ev.x / (setW - Margin)) * 255, 0, 255)
                    app.fgColor = Color { r = c, g = c, b = c }
                end
            end,
            onmouseup = function ()
                selectingColor = false
            end,
            resizeable = true
        }
        -- Optional things
        :tab { id = "options", text = "Options" }
        :check {
            label = "Show Grid",
            onclick = function ()
                app.command.ShowGrid()
            end,
            selected = prefs.show.grid
        }
        :slider {
            id = "previewScale",
            label = "Preview Scale",
            value = PreviewScale * 1.5,
            min = 1,
            max = 6,
            onchange = function ()
                PreviewScale = math.max((set.data.previewScale) / 1.5, 1)
                DrawPreview()
            end
        }
        :button {
            text = "Reset View Angle",
            onclick = function ()
                DragOffsetX = 0
                DragOffsetY = 0
                RepaintPreview()
            end
        }
        :separator {
            label = "Preview Colors"
        }
        :color {
            id = "colHighlight",
            label = "Highlight",
            color = Highlight,
            onchange = function ()
                Highlight = set.data.colHighlight
                CreateCopyImage()
                RepaintPreview()
            end
        }
        :color {
            id = "colMidground",
            label = "Unshaded",
            color = Unshaded,
            onchange = function ()
                Unshaded = set.data.colMidground
                CreateCopyImage()
                RepaintPreview()
            end
        }
        :color {
            id = "colShadow",
            label = "Shaded",
            color = Shaded,
            onchange = function ()
                Shaded = set.data.colShadow
                CreateCopyImage()
                RepaintPreview()
            end
        }
        if not PaletteImage then
            set:file {
                id = "palFile",
                label = "Palette Image",
                open = true,
                onchange = function ()
                    PaletteImage = Image{ fromFile = set.data.palFile }
                    CreateCopyImage()
                    DrawSettings()
                end
            }
        else
            set:button {
                text = "Remove Palette",
                onclick = function ()
                    PaletteImage = nil
                    CreateCopyImage()
                    DrawSettings()
                end
            }
        end
    set:slider {
            id = "startLayer",
            label = "Offset Layer View",
            value = StartLayer,
            min = 1,
            max = 29,
            onchange = function ()
                StartLayer = set.data.startLayer
                CreateCopyImage()
                RepaintPreview()
            end
        }
        :endtabs{ id = "tabs", selected = lastTab }
        :show {
            wait = false,
            bounds = Rectangle(setX, setY, setW, setH),
            autoscrollbars = true,
        }
    DrawPreview()
end

function Change()
    CreateCopyImage()
    DrawSettings()
end
function SpriteChange(ev)
    if not ev.fromUndo then
        Change()
    end
end
function AppChange(ev)
    if ev.name == "Undo" then
        Change()
    end
end

-- repaints the active preview when the active sprite changes
function AttachSprite()
    if (ActiveData and ActiveData.sprite and ActiveData.sprite == app.sprite)
    or (set and set.data.palFile and app.sprite and app.sprite.filename == set.data.palFile) 
    or IgnoreChanges then
        IgnoreChanges = false
        return
    end
    if ActiveData and ActiveData.sprite then
        ActiveData.sprite.events:off(SpriteChange)
        if lyrs then
            lyrs:close()
        end
        if init then
            init:close()
        end
    end
    ActiveData = data:getOrCreate(app.sprite)
    if ActiveData and ActiveData.sprite then
        ActiveData.sprite.events:on('change', SpriteChange)
        Change()
    end
end

function KillScript(ev)
    if ev.name == "RunScript" then
        if set then
            set:close()
        end
        if prv then
            prv:close()
        end
        if lyrs then
            lyrs:close()
        end
        if init then
            init:close()
        end
        app.events:off(KillScript)
        app.events:off(AttachSprite)
        app.events:off(AppChange)
        if ActiveData and ActiveData.sprite then
            ActiveData.sprite.events:off(SpriteChange)
        end
    end
end
app.events:on('sitechange', AttachSprite)
app.events:on('beforecommand', KillScript)
app.events:on('aftercommand', AppChange)
AttachSprite()