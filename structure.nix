{ buildPage, buildBlog }:

{
  index = buildPage "Le site de marius" {} ./index.html "/" null;

  "style.css" = ./style.css;

  blog = buildBlog "Blog de marius" ./blog;
}
