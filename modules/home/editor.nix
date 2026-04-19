{ mkLink, ... }:
{
  xdg.configFile."nvim".source = mkLink "nvim";
}
