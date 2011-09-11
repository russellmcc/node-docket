#~docs/readme.md~ 
## docket 
#
# _The minimalist documentation generator_
#
# *docket* is a tool I created for myself which lets one easily extract 
# github-flavored-markdown from source code.  It isn't particularly smart
# and it doesn't try to do too much, but it's easy to use.  The simple idea 
# is that you should put your documentation in the same place as your code.
#
# The implementation is inspired and uses some code by `docco`.

fs = require "fs"
path = require "path"
showdown = require('./../vendor/showdown').Showdown
child = require 'child_process'

## Configurable, global options
# The _Section Brackets_ are used by docket to parse _Section Identifiers_
section_lbracket = '~'
section_rbracket = '~'

# should we be making html?
html_mode = false
# should we be making .md?
md_mode = false

base_dir = ""

## Implementation

# `section_identifer` is a regex that matches _Section Identifiers_.  
# It's given in string form for easy composition
section_identifier = -> section_lbracket + "([^\\s]*)" + section_rbracket

# `section_header` is a regex that matches _Section Headers_, that is
# _Section Identifiers_ alone on a line.
section_header = -> "^\\s?" + section_identifier() + "\\s?$"

# we use a `language` object to store information about languages.
language = (name, comment_symbol) ->
    @name = name
    @comment_symbol = comment_symbol
    
# information shared between all languages
language.prototype =
    
    # `get_comment` takes a line of text and outputs a comment string or `null`
    # if there is no comment on that line.
    # following `docco`, we only accept single line comments that are not
    # preceded by text.
    get_comment : (line) ->
        # if the `@comment_symbol` is `''`, that means that all lines should be
        # treated as comments.
        return line if @comment_symbol is ''
        
        # otherwise, match anything after the comment symbol when
        # the comment symbol is at the start of the line. 
        comment_regex = new RegExp "^\\s?#{@comment_symbol}(.*)\\s?$"
        (comment_regex.exec line)?[1]

# This is the array of actual languages supported.  If you want more, add them 
# here.
languages =
  '.coffee': new language 'coffee-script', '#'
  '.js': new language 'javascript', '//'
  '.md': new language 'markdown', ''
  
# This looks up the extention in the languages array.
get_language = (sourcepath) -> 
  languages[path.extname(sourcepath)] ? new language 'unknown', ''

# `parse_text` reads text `text` as `language` `lang`, and adds each 
# contained _Docket Section_ to the object `sections`
parse_text = (lang, text, sections) ->
  curr_section = null
  for line in text.split '\n'
    # for each line in the file, try to grab a comment.
    comment = lang.get_comment line
    if not comment?
      curr_section = null
    else
      if curr_section?
        # if we run into any _Section Identifiers_ while in a section,
        # these must be references.
        sections[curr_section] = {} if not sections[curr_section]?
        section_id_regex = (new RegExp section_identifier(), "g")
        while section_id = section_id_regex.exec comment
          sections[curr_section].refs = [] if not sections[curr_section].refs?
          sections[curr_section].refs += [section_id[1]]
        # add the comment to the section.
        sections[curr_section].text = "" if not sections[curr_section].text?
        sections[curr_section].text += comment + "\n"
      else
        # check if this is a _Section Header_, and if so, enter that section
        header_regex = new RegExp section_header()
        header = header_regex.exec comment
        curr_section = header?[1]
  sections

# `read_file` reads a file at path `path` and adds all of its sections to `sections`
read_file = (path, sections, callback) ->
  fs.readFile path, "utf8", (error, text) ->
    throw error if error
    lang = get_language path
    sections = parse_text lang, text, sections
    callback?(sections)
    
# `fill_references` fills in all references to sections in each section.
fill_references = (sections) ->
  sections

# The CSS styles we'd like to apply to the documentation.
docket_styles    = fs.readFileSync(__dirname + '/../resources/docket.css').toString()

# `ensure_directory` ensures that the destination directory exists.
ensure_directory = (srcpath, callback) ->
  dirname = path.dirname srcpath
  child.exec "mkdir -p #{dirname}", ->
    # first, copy in the css
    fs.writeFile dirname + "/docket.css", docket_styles if html_mode
    callback()

# get an html header for a file.
get_html = (title, html) ->
    """
<head>
  <title>#{title}</title>
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
  <link rel="stylesheet" media="all" href="docket.css" />
</head>
<body>
  <table cellpadding="0" cellspacing="0">
      <tbody><tr><td class="docs">#{html}</td></tr></tbody>
  </table>
</body>
    """

# this is a helper that calls read file repeatedly on a number
# of files.
read_files = (paths) -> (sections) ->
  if paths.length
    read_file paths[0], sections, read_files paths.shift
  else
    # finished all the paths - now we have to fill in all references
    sections = fill_references(sections)

    # the outputs are any sections that have the ".md" extension.
    for title, section of sections
      ensure_directory (path.join base_dir,title), ->
       if (/\.md$/.exec title)?
        if md_mode
          fs.writeFile (path.join base_dir,title), section.text
        if html_mode
          title = title.replace /\.md$/, ".html"
          fs.writeFile (path.join base_dir,title), get_html (/\/(.*).html$/.exec title)?[1] ? title, (showdown.makeHtml section.text)
        
exports.perform = (paths, options) ->
  section_lbracket = options?.brackets?[0] ? section_lbracket
  section_rbracket = options?.brackets?[1] ? section_rbracket
  html_mode = options?.html ? html_mode
  base_dir = options?["base-dir"] ? base_dir
  md_mode = options?.markdown ? md_mode
  (read_files paths) {}