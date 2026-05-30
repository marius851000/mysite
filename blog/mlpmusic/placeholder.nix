{ pkgs, ... }:

with pkgs.lib.strings;

let
  escapeHTML = replaceStrings ["<" ">" "\"" "&"] ["&lt;" "&gt;" "&quot;" "&amp;"]; # from https://github.com/styx-static/styx/blob/789127c93bf6a4a337ff1874c986429ac215f5b6/src/renderers/styxlib/template.nix#L273
  generateComparaison = fr_path: en_path: let
    fr_text = builtins.readFile fr_path;
    en_text = builtins.readFile en_path;
    fr_splited = splitString "\n" fr_text;
    en_splited = splitString "\n" en_text;
    replace_empty_with_something = text: if text == "" then "<hr>" else text;
    comparaison_entries = pkgs.lib.lists.zipListsWith (fr: en:
      if fr == "" && en == "" then
        ''<tr><td colspan=2 style="border:none"><hr /></td></tr>''
      else
        "<tr><td>" + (replace_empty_with_something (escapeHTML fr)) + "</td><td>" + (replace_empty_with_something(escapeHTML en)) + "</td><tr>"
    ) fr_splited en_splited;
    comparaison_content = concatStringsSep "\n" comparaison_entries;
  in
    ''
      <table>
        <tr><th>Français</th><th>Anglais</th></tr>
        ${comparaison_content}
      </table>
    '';
in [
  {
    holder = "FLIM_FLAM_COMPARAISON";
    to = generateComparaison ./flim_flam_fr.txt ./flim_flam_en.txt;
  }
  {
    holder = "KIRIN_TALE_COMPARAISON";
    to = generateComparaison ./kirin_tale_fr.txt ./kirin_tale_en.txt;
  }
  {
    holder = "G5_1_COMPARAISON";
    to = generateComparaison ./g5_1_fr.txt ./g5_1_en.txt;
  }
]
