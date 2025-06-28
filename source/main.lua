import "CoreLibs/graphics"
import "CoreLibs/keyboard"
import "CoreLibs/ui"

-- Localizing commonly used globals
-- local pd <const> = playdate
local playdate <const> = playdate
local datastore <const> = playdate.datastore
local geometry <const> = playdate.geometry
local display <const> = playdate.display
local graphics <const> = playdate.graphics
local keyboard <const> = playdate.keyboard
local ui <const> = playdate.ui
local font <const> = graphics.font
local timer <const> = playdate.timer
local simulator <const> = playdate.simulator

local MathParser <const> = import "MathParser"
local parser = MathParser:new()

-- Defining constants
local applicationTitle <const> = string.format("*%s*", graphics.getLocalizedText("applicationTitle"))

local kStandardMode <const> = graphics.getLocalizedText("standardMode")
local kScientificMode <const> = graphics.getLocalizedText("scientificMode")
local kInfoMode <const> = graphics.getLocalizedText("infoMode")
local calculatorModes <const> = {kStandardMode, kScientificMode, kInfoMode}

local screenWidth <const> = display.getWidth()
local screenHeight <const> = display.getHeight()

local systemFont <const> = graphics.getSystemFont()

-- Defining text widths
local applicationTitleTextWidth <const> = graphics.getSystemFont(font.kVariantBold):getTextWidth(applicationTitle)
local aButtonTextWidth <const> = systemFont:getTextWidth(graphics.getLocalizedText("aButtonCompute"))
local bButtonTextWidth <const> = systemFont:getTextWidth(graphics.getLocalizedText("bButtonOpenKeyboard"))
local systemFontHeight <const> = systemFont:getHeight()

-- Defining assets
local buttonImagesSize <const> = 16
local buttonsImage <const> = graphics.imagetable.new("images/playdate-icons-by-minalien")
local aButtonImage <const> = buttonsImage:getImage(6)
local bButtonImage <const> = buttonsImage:getImage(7)

local qrCodeSize <const> = 158
local qrCodeImageScale <const> = 1
local acknowledgementsImage <const> = graphics.image.new("images/acknowledgements")

local backgroundImage <const> = graphics.image.new("images/background")

local standardButtons <const> = {
      "7", "8", "9", "/", "sin",
      "4", "5", "6", "*", "cos",
      "1", "2", "3", "-", "deg",
    "del", "0", ".", "+", "rad"
}
local standardButtonsColumns <const> = 5
local standardButtonsPadding <const> = 1
local standardButtonsSize <const> = 40 - standardButtonsPadding * 2
local standardButtonsGrid <const> = ui.gridview.new(standardButtonsSize, standardButtonsSize)
standardButtonsGrid:setNumberOfColumns(5)
standardButtonsGrid:setNumberOfRows(4)
standardButtonsGrid:setCellPadding(standardButtonsPadding, standardButtonsPadding, standardButtonsPadding, standardButtonsPadding)

function standardButtonsGrid:drawCell(section, row, column, selected, x, y, width, height)
    if selected then
        graphics.fillRoundRect(x, y, width, height, 4)
        graphics.setImageDrawMode(graphics.kDrawModeFillWhite)
    else
        graphics.drawRoundRect(x, y, width, height, 4)
        graphics.setImageDrawMode(graphics.kDrawModeCopy)
    end

    local cellText = standardButtons[(row - 1) * standardButtonsColumns + column]
    graphics.drawTextInRect(cellText, x, y + (height / 2 - systemFontHeight / 2) + 2, width, height, nil, nil, kTextAlignment.center, systemFont)
end

if playdate.isSimulator then
    import "CoreLibs/qrcode"

    graphics.generateQRCode(
        "Made by Domenico Verde (ElGreenoProgramador)\n\
        Thanks to SquidGodDev for making available a Playdate template (https://github.com/SquidGodDev/playdate-template)\n\
        Thanks to Mina Harker for making Playdate 16-bit icons (https://minalien.itch.io/playdate-16px-input-icons)\n\
        Thanks to bytexenon for MathParser.lua (https://github.com/bytexenon/MathParser.lua/blob/main/example.lua)\n\
        Thanks to potch dot me for the tool Playdither (https://www.potch.me/demos/playdither/)",
        0,
        function (image)
            simulator.writeToFile(image, "~/acknowledgements.png")
        end
    )
end

-- Defining variables
local standardFormula = ""
local standardOutputValue = ""

local scientificFormula = ""
local scientificOutputValue = ""

-- Setting graphics
display.setRefreshRate(20)

-- Restore game data
local applicationData = datastore.read()
if applicationData == nil then
    applicationData = {
        currentCalculatorMode = kStandardMode,
        openKeyboardWithCrank = true,
        scientificHistory = "",
    }

    datastore.write(applicationData)
end

-- Preparing system menu
local menu = playdate.getSystemMenu()
local calculatorModeMenu = menu:addOptionsMenuItem(graphics.getLocalizedText("calculatorModeMenu"), calculatorModes, applicationData.currentCalculatorMode, function (mode)
    applicationData.currentCalculatorMode = mode
    datastore.write(applicationData)
end)

local keyboardCrankMenu = menu:addCheckmarkMenuItem(graphics.getLocalizedText("useCrankMenu"), applicationData.openKeyboardWithCrank, function (value)
    applicationData.openKeyboardWithCrank = value
    datastore.write(applicationData)
end)

-- Preparing keyboard
keyboard.textChangedCallback = function ()
    scientificFormula = keyboard.text
end

-- Preparing crank
playdate.crankUndocked = function ()
    if applicationData.openKeyboardWithCrank and applicationData.currentCalculatorMode == kScientificMode then
        keyboard.show(scientificFormula)
    end
end

playdate.crankDocked = function ()
    if applicationData.openKeyboardWithCrank then
        keyboard.hide()
    end
end

-- Drawing
local function drawStandardCalculatorMode()
    keyboard.hide()

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        standardButtonsGrid:selectPreviousRow(true)
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        standardButtonsGrid:selectNextRow(true)
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        standardButtonsGrid:selectPreviousColumn(true)
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        standardButtonsGrid:selectNextColumn(true)
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        local section, row, column = standardButtonsGrid:getSelection()
        local cellText = standardButtons[(row - 1) * standardButtonsColumns + column]

        if cellText == "del" then
            standardFormula = string.sub(standardFormula, 1, -2)
        elseif cellText == "sin" or cellText == "cos" or cellText == "deg" or cellText == "rad" then
            standardFormula = string.format("%s(%.6f)", cellText, standardFormula)

            xpcall(
                function () standardOutputValue = tostring(parser:solve(standardFormula)) end,
                function (err)
                    standardOutputValue = err
                    print(err)
                end
            )
        else
            standardFormula = standardFormula .. cellText
        end
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        xpcall(
            function () standardOutputValue = tostring(parser:solve(standardFormula)) end,
            function (err)
                standardOutputValue = err
                print(err)
            end
        )
    end

-- Drawing for input area
    graphics.drawText(string.format("*%s*", graphics.getLocalizedText("inputEntry")), 10, 24)

    graphics.drawRoundRect(8, 44, 164, 104, 4)
    graphics.drawTextInRect(standardFormula, 12, 48, 160, 100, nil, "...", nil, systemFont)

    -- Text area (external and internal) for output
    graphics.drawText(string.format("*%s*", graphics.getLocalizedText("outputEntry")), 10, 154)

    graphics.drawRoundRect(8, 174, 164, 32, 4)
    graphics.drawTextInRect(standardOutputValue, 12, 178, 160, 28, nil, "...", nil, systemFont)

    -- Drawing buttons grid
    graphics.drawText(string.format("*%s*", graphics.getLocalizedText("keyboardEntry")), 182, 24)
    standardButtonsGrid:drawInRect(184, 45, 208, 200)

    -- Bottom side
    if aButtonImage ~= nil then
        aButtonImage:draw(4, screenHeight - buttonImagesSize - 4)
        graphics.drawText(graphics.getLocalizedText("aButtonPress"), buttonImagesSize + 8, screenHeight - buttonImagesSize - 4)
    else
        graphics.drawText(graphics.getLocalizedText("aButtonError"), 4, screenHeight - buttonImagesSize)
    end

    if bButtonImage ~= nil then
        bButtonImage:draw(20 + buttonImagesSize + aButtonTextWidth, screenHeight - buttonImagesSize - 4)
        graphics.drawText(graphics.getLocalizedText("bButtonCompute"), 24 + buttonImagesSize * 2 + aButtonTextWidth, screenHeight - buttonImagesSize - 4)
    else
        -- Unexpected but, if it happens, this row will be a little lower than the one for A button error
        graphics.drawText(graphics.getLocalizedText("bButtonError"), 4, screenHeight - buttonImagesSize + 4)
    end
end

local function drawScientificCalculatorMode()
    -- Drawing for input area
    graphics.drawText(string.format("*%s*", graphics.getLocalizedText("inputEntry")), 10, 24)

    graphics.drawRoundRect(8, 44, 188, 104, 4)
    graphics.drawTextInRect(scientificFormula, 12, 48, 184, 100, nil, "...", nil, systemFont)

    -- Text area (external and internal) for output
    graphics.drawText(string.format("*%s*", graphics.getLocalizedText("outputEntry")), 10, 154)

    graphics.drawRoundRect(8, 174, 188, 32, 4)
    graphics.drawTextInRect(scientificOutputValue, 12, 178, 184, 28, nil, "...", nil, systemFont)

    -- Listing of computation history
    graphics.drawText(string.format("*%s*", graphics.getLocalizedText("historyEntry")), 206, 24)

    graphics.drawRoundRect(204, 44, 188, 104, 4)
    graphics.drawTextInRect(applicationData.scientificHistory, 208, 48, 184, 100, nil, "...", nil, systemFont)

    if playdate.buttonJustPressed(playdate.kButtonA) then
        xpcall(
            function () scientificOutputValue = tostring(parser:solve(scientificFormula)) end,
            function (err) scientificOutputValue = err end
        )
    end

    -- Bottom side
    if aButtonImage ~= nil then
        aButtonImage:draw(4, screenHeight - buttonImagesSize - 4)
        graphics.drawText(graphics.getLocalizedText("aButtonCompute"), buttonImagesSize + 8, screenHeight - buttonImagesSize - 4)
    else
        graphics.drawText(graphics.getLocalizedText("aButtonError"), 4, screenHeight - buttonImagesSize)
    end

    -- Draw crank indicator if crank is docked
    if applicationData.openKeyboardWithCrank then
        if playdate.isCrankDocked() then
            ui.crankIndicator:draw()
        end
    else
        if bButtonImage ~= nil then
            bButtonImage:draw(20 + buttonImagesSize + aButtonTextWidth, screenHeight - buttonImagesSize - 4)
            graphics.drawText(graphics.getLocalizedText("bButtonOpenKeyboard"), 24 + buttonImagesSize * 2 + aButtonTextWidth, screenHeight - buttonImagesSize - 4)
        else
            -- Unexpected but, if it happens, this row will be a little lower than the one for A button error
            graphics.drawText(graphics.getLocalizedText("bButtonError"), 4, screenHeight - buttonImagesSize + 4)
        end

        if playdate.buttonJustReleased(playdate.kButtonB) then
            keyboard.show(scientificFormula)
        end
    end
end

local function drawInfoMode()
    keyboard.hide()

    if acknowledgementsImage then
        local offset = qrCodeSize * qrCodeImageScale / 2
        acknowledgementsImage:drawScaled(200 - offset, 120 - offset, qrCodeImageScale)
    else
        graphics.drawText("Acknowledgements QR code not found!", 200, 120)
    end
end

-- playdate.update function is required in every project!
function playdate.update()
    -- Clear screen
    graphics.clear()

    if backgroundImage and applicationData.currentCalculatorMode ~= kInfoMode then
        backgroundImage:draw(0, 0)
    end

    graphics.drawText(applicationTitle, 4, 4)
    graphics.drawText(applicationData.currentCalculatorMode, applicationTitleTextWidth, 4)

    if applicationData.currentCalculatorMode == kStandardMode then
        drawStandardCalculatorMode()
    elseif applicationData.currentCalculatorMode == kScientificMode then
        drawScientificCalculatorMode()
    elseif applicationData.currentCalculatorMode == kInfoMode then
        drawInfoMode()
    end

    timer.updateTimers()
end
