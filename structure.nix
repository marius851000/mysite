{ buildPage, buildBlog }:

{
  index = buildPage {
    title = "Le site de marius";
    lang = "fr";
    description = "Site personnel de Marius";
  } ./index.html "/" null;

  "style.css" = ./style.css;

  blog = buildBlog "Blog de marius" ./blog;
}
