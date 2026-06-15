{ pkgs, ... }: rec {

  siteroot = "https://mariusdavid.fr";
  urlFromPath = path: "${siteroot}${path}/";

  createCreativeWorkShortMeta = extra_meta: let
    lang = extra_meta.lang;

    publication_date_span = "<span itemprop=\"datePublished\" content=\"${dateToDefaultISO8601 extra_meta."date"}\">";
    publication_date_text = if (extra_meta ? "date") then (
      if lang == "en" then (
        "Published on ${publication_date_span}${formatDateEnglish extra_meta.date}</span>"
      ) else if lang == "fr" then (
        "Publié le ${publication_date_span}${formatDateFrench extra_meta.date}</span>"
      ) else throw "publication date: unknown language ${lang}"
    ) else null;

    modification_date_span = "<span itemprop=\"dateModified\" content=\"${dateToDefaultISO8601 extra_meta."date"}\">";
    modification_date_text = if (extra_meta ? "modified-date") then (
      if lang == "en" then (
        "Last changed on ${modification_date_span}${formatDateEnglish extra_meta."modified-date"}</span>"
      ) else if lang == "fr" then (
        "Modifié le ${modification_date_span}${formatDateFrench extra_meta."modified-date"}</span>"
      ) else throw "modification date: unknown language ${lang}"
    ) else null;

    post_title_stuff = (if (extra_meta ? "description" && !(extra_meta ? "displayDescription" && extra_meta.displayDescription == false)) then (
        "<p class=\"article-headline\">${extra_meta.description}</p>\n" #TODO: what is the appropriate type?
      ) else "") +
      (if (publication_date_text != null && modification_date_text != null) then (
        "<p class=\"article-meta\"><i>${publication_date_text} (${modification_date_text})</i></p>\n"
      ) else if (publication_date_text != null) then (
        "<p class=\"article-meta\"><i>${publication_date_text}</i></p>\n"
      ) else if (modification_date_text != null) then (
        "<p class=\"article-meta\"><i>${modification_date_text}</i></p>\n"
      ) else "");
  in post_title_stuff;

  formatItemScopeArgs = type: id: prop: if prop != null then
    "itemscope itemtype=\"${type}\" itemid=\"${id}\" itemprop=\"${prop}\""
  else
    "itemscope itemtype=\"${type}\" itemid=\"${id}\"";

  formatPersonFromData = data: root: prop: "<span ${formatItemScopeArgs "https://schema.org/Person" data."${root}Url" prop} class=\"personName\"><a href=\"${data."${root}Url"}\" itemprop=\"url\"><span itemprop=\"name\">${data."${root}Name"}</span></a></span>";

  formatWorkFromData = data: root: lang: prop: let
    type = data."${root}Type";
    isBook = type == "book";
    url = data."${root}Url";


    ebookMapping = {
      "EBook" = {
        "en" = "EBook";
        "fr" = "livre numérique";
      };
    };

    bookFormat = if isBook && (data ? "${root}BookFormat") then data."${root}BookFormat" else null;
    bookIsFree = if isBook && (data ? "${root}IsAccessibleForFree") then data."${root}IsAccessibleForFree" else null;
    formattedTags = []
      ++ (if (bookFormat != null) then [
        "<span itemprop=\"bookFormat\" content=\"${bookFormat}\">${ebookMapping.${bookFormat}.${lang}}</span>"
      ] else [])
      ++ (if (bookIsFree == true) then [
        "<span itemprop=\"isAccessibleForFree\" content=\"True\">${{"fr"="gratuit"; "en"="gratis";}."${lang}"}</span>"
      ] else if (bookIsFree == false) then [
        "<span itemprop=\"isAccessibleForFree\" content=\"False\">${{"fr"="payant"; "en"="paid";}."${lang}"}</span>"
      ] else []);

    mainTags = if type == "book" then
      {
        "type" = "https://schema.org/Book";
      }
    else
      throw "formatWorkFromData: unsupported type: ${type}";

    tagsTogether = if (builtins.length formattedTags) > 0 then
        "(${builtins.concatStringsSep ", " formattedTags})"
      else
        "";

  in ''
    <span ${formatItemScopeArgs mainTags.type url prop}>
      <span class="workTitle" itemprop="name"><a href="${url}" itemprop="url">${data."${root}Name"}</a></span>
      ${{"fr" = " par "; "en" = " by ";}.${lang}}
      ${formatPersonFromData data "${root}Author" "author"}
      ${tagsTogether}
    </span>
  '';

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
