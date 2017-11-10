# template=/dev/null to ignore any global templatedir the developer may have
# configured on their machine. Pipe to /dev/null to ignore the warning about
# no template dir found.
def suppressed_git_init
  `git init --template=/dev/null 2> /dev/null`
end
