# Import the module
Import-Module InteractiveMenu

# Define the items for the menu
# Note: the url, info, selected and readonly parameters are optional
$menuItems = @(
    Get-InteractiveMultiMenuOption `
        -Item "option1" `
        -Label "First Option" `
        -Order 0 `
        -Info "First option info" `
        -Url "https://example.com"
    Get-InteractiveMultiMenuOption `
        -Item "option2" `
        -Label "Second Option" `
        -Order 1 `
        -Info "Second option info" `
        -Url "https://example.com" `
        -Selected `
        -Readonly
)

# [Optional] You can change the colors and the symbols
$options = @{
    HeaderColor = [ConsoleColor]::Magenta;
    HelpColor = [ConsoleColor]::Cyan;
    CurrentItemColor = [ConsoleColor]::DarkGreen;
    LinkColor = [ConsoleColor]::DarkCyan;
    CurrentItemLinkColor = [ConsoleColor]::Black;
    MenuDeselected = "[ ]";
    MenuSelected = "[x]";
    MenuCannotSelect = "[/]";
    MenuCannotDeselect = "[!]";
    MenuInfoColor = [ConsoleColor]::DarkYellow;
    MenuErrorColor = [ConsoleColor]::DarkRed;
}

# Define the header of the menu
$header = "Choose your options"

# Trigger the menu and receive the user selections
# Note: the options parameter is optional
$selectedOptions = Get-InteractiveMenuUserSelection -Header $header -Items $menuItems -Options $options