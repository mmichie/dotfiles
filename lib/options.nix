{ lib }:
let
  inherit (lib) mkOption types;
in
{
  mkOpt' =
    type: default: description:
    mkOption { inherit type default description; };
  mkBoolOpt =
    default:
    mkOption {
      inherit default;
      type = types.bool;
      example = true;
    };
}
