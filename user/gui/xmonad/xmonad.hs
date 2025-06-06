import XMonad

main = xmonad $ def
  {
    terminal = "kitty",
    modMask = mod4Mask,
    borderWidth = 2,
    normalBorderColor = "#dddddd",
    focusedBorderColor = "#ff0000"
  }
