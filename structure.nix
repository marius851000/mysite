{ buildPage, buildBlog }:

{
  index = buildPage "Le site de marius" ./index.html;

  "style.css" = ./style.css;

  blog = buildBlog "Blog de marius" ./blog;
}