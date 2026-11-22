if not app.isUIAvailable then
    return
end

-- shorthands
local fs = app.fs
local pc = app.pixelColor

---@return string
---@param s table
local function joinPath(s)
    local path = ""
    for index, value in ipairs(s) do
        if type(value) == "string" then
            path = path .. value
            if index ~= #s then
                path = path .. app.fs.pathSeparator
            end
        end
    end
    return path
end

-- math functions
function Clamp(x, a, b)
	return math.max(a, math.min(b, x));
end

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

---@param i number
---@return integer
function math.round(i)
    local decimal = i - math.floor(i)
    return decimal < 0.5 and math.floor(i) or math.ceil(i)
end

---@param x Color
---@param y Color
---@return Color
function Multcol(x, y)
	return Color{
        red = math.round((x.red / 255) * (y.red / 255) * 255),
        green = math.round((x.green / 255) * (y.green / 255) * 255),
        blue = math.round((x.blue / 255) * (y.blue / 255) * 255)
    }
end

---@param x Color
---@param y number
---@return Color
function Multcol2(x, y)
    return Color{
        red = math.round((x.red / 255) * y * 255),
        green = math.round((x.green / 255) * y * 255),
        blue = math.round((x.blue / 255) * y * 255)
    }
end

local boolToInt = function (b)
    return b and 1 or 0
end

-- table with inner tables that contain effect color pixel colors
-- taken from Alduris's web app (thanks Alduris you're epic)
local effectColorTable = {
    --fg            fg shade        bg              bg shade        fg rain         fg shade rain   bg rain         bg shade rain
    {{255,0,233},   {137,42,129},   {255,157,247},  {183,137,179},  {84,26,79},     {84,26,79},     {60,39,58},     {60,39,58}},
    {{255,0,233},   {255,0,233},    {255,157,247},  {255,157,247},  {255,0,233},    {255,0,233},    {255,157,247},  {255,157,247}},
    {{255,2,90},    {150,0,52},     {255,109,160},  {161,40,82},    {90,29,50},     {90,29,50},     {92,49,75},     {92,49,75}},
    {{45,255,154},  {27,188,110},   {156,255,207},  {119,211,167},  {21,147,86},    {21,147,86},    {65,116,91},    {65,116,91}},
    {{45,255,154},  {45,255,154},   {156,255,207},  {156,255,207},  {45,255,154},   {45,255,154},   {156,255,207},  {156,255,207}},
    {{33,255,109},  {68,156,98},    {113,223,152},  {105,180,131},  {60,128,83},    {60,128,83},    {72,112,85},    {72,112,85}},
    {{188,204,0},   {113,120,26},   {173,183,64},   {134,140,59},   {87,93,20},     {87,93,20},     {74,76,32},     {74,76,32}},
    {{138,255,0},   {95,135,47},    {159,210,100},  {129,163,88},   {74,105,37},    {74,105,37},    {71,89,48},     {71,89,48}},
    {{0,255,24},    {47,135,55},    {100,210,111},  {88,163,95},    {37,105,43},    {37,105,43},    {48,89,52},     {48,89,52}},
    {{255,255,255}, {205,205,205},  {255,255,255},  {205,205,205},  {205,205,205},  {205,205,205},  {205,205,205},  {205,205,205}},
    {{33,149,255},  {68,114,156},   {113,169,223},  {105,144,180},  {60,96,128},    {60,96,128},    {72,94,112},    {72,94,112}},
    {{33,149,255},  {33,149,255},   {113,169,223},  {113,169,223},  {33,149,255},   {33,149,255},   {113,169,223},  {113,169,223}},
    {{0,47,217},    {2,39,165},     {24,66,229},    {37,66,178},    {7,36,133},     {7,36,133},     {32,52,106},    {32,52,106}},
    {{255,133,0},   {135,93,47},    {210,158,100},  {163,127,88},   {105,72,37},    {105,72,37},    {89,69,48},     {89,69,48}},
    {{255,161,0},   {255,161,0},    {255,210,132},  {255,210,132},  {255,161,0},    {255,161,0},    {255,210,132},  {255,210,132}},
    {{255,187,38},  {231,159,0},    {255,202,85},   {253,183,36},   {196,134,0},    {196,134,0},    {156,118,37},   {156,118,37}},
    {{141,2,255},   {83,0,150},     {189,109,255},  {107,40,161},   {63,29,90},     {63,29,90},     {62,49,92},     {62,49,92}},
    {{141,2,255},   {141,2,255},    {189,109,255},  {189,109,255},  {141,2,255},    {141,2,255},    {189,109,255},  {189,109,255}},
    {{255,6,2},     {150,3,0},      {255,111,109},  {161,42,40},    {90,30,29},     {90,30,29},     {92,49,59},     {92,49,59}},
    {{255,6,2},     {255,6,2},      {255,111,109},  {255,111,109},  {255,6,2},      {255,6,2},      {255,111,109},  {255,111,109}},
    {{0,0,255},     {0,0,255},      {0,0,255},      {0,0,255},      {0,0,255},      {0,0,255},      {0,0,255},      {0,0,255}},
    {{0,0,0},       {0,0,0},        {0,0,0},        {0,0,0},        {0,0,0},        {0,0,0},        {0,0,0},        {0,0,0}}
}
local effectColNumbers = {}
for effNum, array in ipairs(effectColorTable) do
    table.insert(effectColNumbers, effNum) -- our table for selecting the avaliable effect colors
    for index, value in ipairs(array) do -- Convert all of our table values to a readable Color class for Aseprite
        effectColorTable[effNum][index] = Color{ red = value[1], green = value[2], blue = value[3] }
    end
end

---@return Sprite[]
---@return Sprite[]
local updateActiveSprites = function ()
    local fileSprites = {}
    local paletteSprites = {}
    for _, v in ipairs(app.sprites) do
        if v and v.filename and string.match(fs.fileName(v.filename), "palette") and v.width == 32 and v.height == 16 then
            table.insert(paletteSprites, v)
        elseif v.filename then
            table.insert(fileSprites, v)
        end
    end
    return fileSprites, paletteSprites
end
local f, p = updateActiveSprites()

-- script UI variables
local dlgX = 100
local dlgY = 100
local dlgW = 200
local dlgH = 330
local dlg = nil
local dlgImages = {}
local selectedFile = nil

---@return table|nil
local function getSel()
    return selectedFile and dlgImages[selectedFile] or nil
end

---@return Image
local function getLayerImage(layer)
    return layer:cel(1).image
end

-- grab our effect color
local function effCol(s, AorB, bg, shade)
    if not s.effectA then
        s.effectA = 0
    end
    if not s.effectB then
        s.effectB = 2
    end
    local col = (AorB and s.effectA or s.effectB) + 1;
    bg = boolToInt(bg)
    shade = boolToInt(shade)
    return LerpCol(
        effectColorTable[col][1 + shade + (bg * 2)],
        effectColorTable[col][5 + shade + (bg * 2)],
        boolToInt(s.rain)
    )
end

local function renderPalette(sprite, renderEffects)
    if not sprite or not sprite.pixelInformation or not sprite.palette then
        return
    end

    if sprite.layers and sprite.palette then
        local palette = getLayerImage(sprite.palette.layers[1])
        local colorImage = getLayerImage(sprite.layers.color)
        local fogImage = getLayerImage(sprite.layers.fog)
        local effectAImage = getLayerImage(sprite.layers.effA)
        local effectBImage = getLayerImage(sprite.layers.effB)
        local grimeImage = getLayerImage(sprite.layers.grime)
        local decalImage = getLayerImage(sprite.layers.decal)

        local yOff = sprite.rain and 8 or 0
        for y = 1, 9 do
            for x = 1, 33 do
                local pixels = sprite.pixelInformation
                local palColor = Color(palette:getPixel(x - 1, y + yOff - 1))
                if x == 2 and y == 1 then
                    if sprite.fogColor and sprite.fogColor == palColor then
                        goto continue -- if our color matches, skip
                    else
                        sprite.fogColor = palColor
                        if pixels.fogPixels then
                            for _, v in ipairs(pixels.fogPixels) do
                                -- render fog
                                if v.fogDensity and v.fogDensity > 0 then
                                    local fog = sprite.fogColor
                                    fog.alpha = Clamp(v.fogDensity * 100, 0, 100)
                                    fogImage:drawPixel(v.xCoord, v.yCoord, fog)
                                end
                            end
                        end
                    end
                elseif x == 10 and y == 1 then
                    sprite.layers.fog.opacity = Clamp((255 - palColor.red), 0, 255)
                elseif y == 2 then -- grime colors
                    if not sprite.grimeColors then
                        sprite.grimeColors = {}
                    end
                    if sprite.grimeColors[x] and sprite.grimeColors[x] == palColor then
                        goto continue
                    else
                        sprite.grimeColors[x] = palColor
                        if pixels.grimePixels and pixels.grimePixels[x] then
                            for i, v in ipairs(pixels.grimePixels[x]) do
                                grimeImage:drawPixel(v.xCoord, v.yCoord, sprite.grimeColors[x])
                            end
                        end
                    end
                    if not sprite.rendered then
                        sprite.layers.grime.opacity = math.round(255 * 0.2)
                    end
                else
                    if pixels[x] and pixels[x][y] then
                        local renderAll = true
                        if pixels[x][y].lastColor and pixels[x][y].lastColor == palColor then
                            renderAll = false -- if our color matches the last value, then skip rendering
                        end
                        pixels[x][y].lastColor = palColor
                        for _, v in ipairs(pixels[x][y]) do
                            if renderAll then
                                local finalCol = palColor
                                if v.effectWhite then
                                    finalCol = LerpCol(palColor, Color{red = 255, green = 255, blue = 255}, v.effectWhite)
                                end
                                colorImage:drawPixel(v.xCoord, v.yCoord, finalCol)
                                if not sprite.rendered then
                                    -- render fog
                                    if sprite.fogColor and v.fogDensity and v.fogDensity > 0 then
                                        local fog = sprite.fogColor
                                        fog.alpha = v.fogDensity * 100
                                        fogImage:drawPixel(v.xCoord, v.yCoord, fog)
                                    end
                                end
                            end
                            
                            if renderEffects then
                                -- render effect colors
                                if v.effectAmt and v.effectAmt > 0 then
                                    local effectCol = LerpCol(
                                        effCol(sprite, v.effectAorB, false, v.shadow),
                                        effCol(sprite, v.effectAorB, true, v.shadow),
                                        (x - 1) / 30
                                    )
                                    local effString = v.effectAorB and "a" or "b"
                                    if sprite[effString .. "Hue"] and sprite[effString .. "Hue"] > 0 then
                                        effectCol.hue = math.fmod(math.fmod((effectCol.hue / 255) + (sprite[effString .. "Hue"] / 255), 1), 1) * 255
                                    end
                                    if sprite[effString .. "Sat"] then
                                        effectCol.saturation = Clamp((effectCol.saturation / 255) * ((sprite[effString .. "Sat"] / 255) * 2), 0, 1) * 255
                                    end
                                    if sprite[effString .. "Val"] then
                                        effectCol.value = Clamp((effectCol.value / 255) * ((sprite[effString .. "Val"] / 255) * 2), 0, 1) * 255
                                    end
                                    
                                    effectCol.alpha = v.effectIntensity
                                    local effImage = v.effectAorB and effectAImage or effectBImage
                                    effImage:drawPixel(v.xCoord, v.yCoord, effectCol)
                                end
    
                                if v.effectAmt == 100 and v.decalCol then
                                    local dCol = v.decalCol
                                    dCol = LerpCol(LerpCol(palColor, dCol, 0.7), Multcol2(Multcol(palColor, dCol), 0.5), Lerp(0.9, 0.3 + 0.4 * boolToInt(v.shadow), Clamp((v.depth-3.5)*0.3, 0, 1)));
                                    decalImage:drawPixel(v.xCoord, v.yCoord, dCol)
                                end
                            end
                        end
                    end
                end
                ::continue::
            end
        end
        sprite.rendered = true
        app.command.Refresh()
        ReloadDlg()
    end
end

---@param s Sprite
---@param name string
---@param create boolean
---@return Layer|nil
local function getOrCreateLayer(s, name, create)
    if s and #s.layers > 0 then
        for _, v in ipairs(s.layers) do
            if v.name == name and #v.cels > 0 then
                v.isEditable = false
                return v
            end
        end

        if not create then
            s.layers[1].isEditable = false
            s.layers[1].name = name
            return s.layers[1]
        end
    end

    -- if the layer doesn't exist, return a new layer
    if create then
        local group = nil
        local groupName = "Render Layers"
        if s and #s.layers > 0 then
            for _, v in ipairs(s.layers) do
                if v.name == groupName and v.isGroup then
                    group = v
                    break
                end
            end
        end
        if not group then
            group = s:newGroup()
            group.name = groupName
        else
            if #group.layers > 0 then
                for _, v in ipairs(group.layers) do
                    if v.name == name then
                        v.isEditable = false
                        return v
                    end
                end
            end
        end

        local layer = s:newLayer()
        layer.name = name
        layer.parent = group
        layer.isEditable = false
        s:newCel(layer, 1)
        return layer
    end
    return nil
end

local function generatePixels(v)
    if not v or not v.tiedSprite then
        app.alert("No active render to bind to!")
        return
    end

    local activeSprite = v.tiedSprite
    local renderLayer = getOrCreateLayer(activeSprite, "Render", false)
    local colorLayer = getOrCreateLayer(activeSprite, "Palette Color", true)
    local decalLayer = getOrCreateLayer(activeSprite, "Decal", true)
    local effBLayer = getOrCreateLayer(activeSprite, "Effect B", true)
    local effALayer = getOrCreateLayer(activeSprite, "Effect A", true)
    local grimeLayer = getOrCreateLayer(activeSprite, "Grime", true)
    local fogLayer = getOrCreateLayer(activeSprite, "Fog", true)

    local grimeMask = app.open(joinPath{app.fs.userConfigPath, "scripts", "GrimeMask.png"} )

    v.layers = { render = renderLayer, color = colorLayer, grime = grimeLayer, decal = decalLayer, effB = effBLayer, effA = effALayer, fog = fogLayer }

    local renderImage = renderLayer and renderLayer:cel(1).image or nil
    if renderImage then
        for x = 0, renderImage.width do
            for y = 0, renderImage.height do
                -- our pixel information
                local pix = {
                    xCoord = x,
                    yCoord = y
                }
    
                -- Get our rendered pixel information
                local rPix = renderImage:getPixel(x, y)
                local r = pc.rgbaR(rPix) -- The red channel is primarly used to describe depth and shadows
                local g = pc.rgbaG(rPix) -- The green channel is used for grime, effects, and decals
                local b = pc.rgbaB(rPix) -- The blue channel is used for color indexing
    
                local gPix = grimeMask and grimeMask.layers[1]:cel(1).image:getPixel(x, y) or nil
                local t = v.pixelInformation

                -- Lets do actual pixel math here
                local xC = 0
                local yC = 0
                if r == 255 and g == 255 and b == 255 then -- Sky
                else -- Not sky
                    pix.notDarkFloor = true
                    if g >= 16 then
                        g = g - 16
                        pix.notDarkFloor = false
                    end
                    if g >= 8 then
                        g = g - 8
                        pix.effectAmt = 100
                    else
                        pix.effectAmt = g
                    end
    
                    pix.shadow = false
                    if r > 90 then
                        r = r - 90
                    else
                        pix.shadow = true
                    end
    
                    local channel = Clamp(math.floor((r-1) / 30), 0, 2) -- red/green/blue
                    r = math.fmod((r-1), 30) -- 0-29
                    xC = r
                    yC = 2 + channel + (boolToInt(pix.shadow) * 3)
    
                    pix.depth = r
                    pix.fogDensity = Clamp(r * (r < 10 and Lerp(boolToInt(pix.notDarkFloor), 1, 0.5) or 1) / 30, 0, 1)
    
                    -- grime
                    if g >= 4 and gPix then
                        pix.rbCol = math.floor(Lerp(0, 31, Color(gPix).red / 255)) + 1
                    end
    
                    -- decal color calculation
                    if pix.effectAmt == 100 then
                        pix.decalCol = Color(renderImage:getPixel(255 - b, 0))
                        if xC == 2 then
                            pix.decalCol = LerpCol(pix.decalCol, Color{ r = 255, g = 255, b = 255}, 0.2 - boolToInt(pix.shadow) * 0.1)
                        end
                        pix.fogDensity = r / 60 -- lerp with fog color
                    elseif g > 0 and g < 3 then
                        -- effect colors
                        pix.effectAorB = g == 1
                        pix.effectIntensity = b
                    elseif g == 3 then
                        pix.effectWhite = b / 255
                    end
                end
    
                -- index both to bring them to 1
                xC = xC + 1
                yC = yC + 1
    
                if not t[xC] then
                    t[xC] = {}
                end
                if not t[xC][yC] then
                    t[xC][yC] = {}
                end

                if pix.fogDensity and pix.fogDensity > 0 then
                    if not t.fogPixels then
                        t.fogPixels = {}
                    end
                    table.insert(t.fogPixels, pix)
                end
                if pix.rbCol then
                    if not t.grimePixels then
                        t.grimePixels = {}
                    end
                    if not t.grimePixels[pix.rbCol] then
                        t.grimePixels[pix.rbCol] = {}
                    end
                    table.insert(t.grimePixels[pix.rbCol], pix)
                end
                -- Set our pixel in the pixel storage
                table.insert(t[xC][yC], pix)
            end
        end
    end
    if grimeMask then
        app.command.CloseFile()
    end
    ReloadDlg()
end

---@param v Sprite
local function ImageInfo(v)
    return {
        tiedSprite = v,
        pixelInformation = {},
        rendered = false,
        palette = nil
    }
end

function OnDraw()
    if dlgImages and selectedFile then
        local v = dlgImages[selectedFile]
        if v and v.palette == app.site.sprite and v.tiedSprite then
            renderPalette(v, false)
        end
    end
end

---@param sprite Sprite
---@param b boolean
local function BindSprite(sprite, b)
    if b then
        sprite.events:on('change', OnDraw)
    else
        sprite.events:off(OnDraw)
    end
end

function ReloadDlg()
    if dlg then
        dlgX = dlg.bounds.x
        dlgY = dlg.bounds.y
        dlgW = dlg.bounds.w
        dlgH = dlg.bounds.h
        dlg:close()
    end
    dlg = Dialog{
        title = "RW Live Palette Previewer"
    }
    f, p = updateActiveSprites()
    for i, v in ipairs(f) do
        if v then
            local file = fs.fileName(v.filename)
            dlg:button{
                id = file,
                text = file,
                selected = selectedFile and selectedFile == v.filename or false,
                onclick = function ()
                    if not dlgImages[file] then
                        dlgImages[file] = ImageInfo(v)
                    end
                    selectedFile = file
                    ReloadDlg()
                end
            }
        end
        if math.fmod(i, 2) == 0 then
            dlg:newrow()
        end
    end

    dlg:newrow()
    dlg:separator()

    if selectedFile and getSel() and getSel().tiedSprite then
        if getSel().pixelInformation and #getSel().pixelInformation > 0 then
            local palettes = {}
            for i, v in ipairs(p) do
                local name = fs.fileName(v.filename)
                table.insert(palettes, name)
                palettes[name] = v
            end
            dlg:combobox {
                id = "palette",
                label = "Palette",
                option = (selectedFile and getSel() and getSel().palette) and fs.fileName(getSel().palette.filename) or (palettes and palettes[1] or ""),
                options = palettes,
                onchange = function ()
                    if dlg.data.palette and getSel() then
                        getSel().palette = palettes[dlg.data.palette]
                        if getSel().rendered then
                            renderPalette(getSel(), true)
                        end
                    end
                end
            }
            if not getSel().palette and #palettes > 0 then
                getSel().palette = palettes[palettes[#palettes]]
            end
        
            if not getSel().bound and getSel().palette then
                dlg:button{
                    id = "render",
                    text = "Bind Render",
                    onclick = function ()
                        renderPalette(getSel(), true)
                        BindSprite(getSel().palette, true)
                        getSel().bound = true
                    end
                }
            elseif getSel().bound then
                dlg:newrow()
                dlg:button{
                    id = "unbind",
                    text = "Unbind Render",
                    onclick = function ()
                        if getSel()and getSel().palette and getSel().bound then
                            BindSprite(getSel().palette, false)
                        end
                    end
                }
                -- all of our values
                dlg:check{
                    id = "rain",
                    text = "Rain Palette?",
                    selected = getSel() and getSel().rain or false,
                    onclick = function ()
                        if getSel()then
                            getSel().rain = not getSel().rain
                            getSel().rendered = false
                            renderPalette(getSel(), true)
                        end
                    end
                }
                dlg:slider{
                    id = "grime",
                    label = "Grime",
                    min = 0,
                    max = 255,
                    value = (selectedFile and getSel() and getSel().layers) and getSel().layers.grime.opacity or math.round(255 * 0.2),
                    onchange = function ()
                        if selectedFile and getSel() and getSel().layers and dlg.data.grime then
                            getSel().layers.grime.opacity = math.round(dlg.data.grime * 0.2)
                            app.command.Refresh()
                        end
                    end
                }
                ---@param key string
                local function setEffectAndRender(key)
                    if getSel()and dlg.data[key] then
                        getSel()[key] = dlg.data[key]
                        renderPalette(getSel(), true)
                    end
                end
                dlg:combobox{
                    id = "effectA",
                    label = "Effect Color A",
                    option = getSel()and tostring(getSel().effectA) or tostring(1),
                    options = effectColNumbers,
                    onchange = function ()
                        setEffectAndRender("effectA")
                    end
                }
                dlg:label{
                    id = "modA",
                    text = "Modify Effect Color A"
                }
                dlg:slider{
                    id = "aHue",
                    label = "Hue",
                    min = 0,
                    max = 255,
                    value = getSel()and getSel().aHue or 0,
                    onrelease = function ()
                        setEffectAndRender("aHue")
                    end
                }
                dlg:slider{
                    id = "aSat",
                    label = "Saturation",
                    min = 0,
                    max = 255,
                    value = getSel()and getSel().aSat or 128,
                    onrelease = function ()
                        -- change saturation
                        setEffectAndRender("aSat")
                    end
                }
                dlg:slider{
                    id = "aVal",
                    label = "Value",
                    min = 0,
                    max = 255,
                    value = getSel()and getSel().aVal or 128,
                    onrelease = function ()
                        setEffectAndRender("aVal")
                    end
                }
                dlg:separator()
                
                dlg:combobox{
                    id = "effectB",
                    label = "Effect Color B",
                    option = getSel()and tostring(getSel().effectB) or tostring(3),
                    options = effectColNumbers,
                    onchange = function ()
                        setEffectAndRender("effectB")
                    end
                }
                dlg:label{
                    id = "modB",
                    text = "Modify Effect Color B"
                }
                dlg:slider{
                    id = "bHue",
                    label = "Hue",
                    min = 0,
                    max = 255,
                    value = getSel()and getSel().bHue or 0,
                    onrelease = function ()
                        -- change hue
                        setEffectAndRender("bHue")
                    end
                }
                dlg:slider{
                    id = "bSat",
                    label = "Saturation",
                    min = 0,
                    max = 255,
                    value = getSel()and getSel().bSat or 128,
                    onrelease = function ()
                        -- change hue
                        setEffectAndRender("bSat")
                    end
                }
                dlg:slider{
                    id = "bVal",
                    label = "Value",
                    min = 0,
                    max = 255,
                    value = getSel()and getSel().bVal or 128,
                    onrelease = function ()
                        -- change hue
                        setEffectAndRender("bVal")
                    end
                }
            end
        else
            dlg:button {
                id = "generate",
                text = "Generate Data",
                onclick = function ()
                    if selectedFile then
                        generatePixels(getSel())
                    end
                end
            }
        end
    end

    dlg:show {
        wait = false,
        bounds = Rectangle(dlgX, dlgY, dlgW, dlgH)
    }
end
ReloadDlg()

app.events:on('aftercommand', function (ev)
    if ev.name == "OpenFile" and dlg then
        ReloadDlg()
    end
end)
app.events:on('sitechange', function ()
    if dlg then
        ReloadDlg()
    end
end)