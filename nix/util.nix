{ pkgs, ... }: rec {

  siteroot = "https://mariusdavid.fr";
  urlFromPath = path: "${siteroot}${path}/";

  formatDateEnglish = dateStr: let
    parts = pkgs.lib.strings.splitString "-" dateStr;
    year = builtins.head parts;
    monthIdx = builtins.elemAt parts 1;
    day = builtins.elemAt parts 2;

    months = [
      "January" "February" "March" "April" "May" "June"
      "July" "August" "September" "October" "November" "December"
    ];

    month = builtins.elemAt months (pkgs.lib.toIntBase10 monthIdx - 1);
  in "${month} ${day}, ${year}";

  formatDateFrench = dateStr: let
    parts = pkgs.lib.strings.splitString "-" dateStr;
    year = builtins.head parts;
    monthIdx = builtins.elemAt parts 1;
    day = builtins.elemAt parts 2;

    months = [
      "janvier" "février" "mars" "avril" "mai" "juin"
      "juillet" "août" "septembre" "octobre" "novembre" "décembre"
    ];

    month = builtins.elemAt months (pkgs.lib.toIntBase10 monthIdx - 1);

    dayFormatted = if pkgs.lib.toIntBase10 day == 1 then "1er" else day;
  in "${dayFormatted} ${month} ${year}";

  dateToDefaultISO8601 = dateStr: "${dateStr}T12:00:00+02:00";
}
