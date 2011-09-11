fs = require 'fs'
child = require 'child_process'

task 'doc', 'create md and html doc files', (options) ->
    child.exec 'docket lib/* -m'
    child.exec 'docket lib/* -d doc_html'