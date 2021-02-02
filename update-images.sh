#!/bin/sh
# scan images and check for any updates

# in Visual Pardigm, export all diagrams to: "${incoming}"
incoming='VPProjects'
outgoing='images'


ERROR() {
  printf 'error: '
  printf "${@}"
  printf '\n'
  exit 1
}


# main program
for p in cmp awk cp rm
do
  f="$(command -v "${p}")"
  [ -x "${f}" ] || ERROR 'cannot find program: %s' "${p}"
done


awk -v incoming="${incoming}" -v outgoing="${outgoing}" '

BEGIN {
  in_cmd = "find " incoming " -type f"
  out_cmd = "find " outgoing " -type f"

  delete src
  delete dst

  while((in_cmd | getline line) > 0) {
     base = line
     sub("^.*/", "", base)
     src[base] = line
  }
  close(in_cmd)

  while((out_cmd | getline line) > 0) {
     base = line
     sub("^.*/", "", base)
     dst[base] = line
  }
  close(out_cmd)

  for (f in dst) {
    s = src[f]
    d = dst[f]
    delete src[f]
    if (s) {
      rc = system("cmp -s \"" s "\" \"" d "\"")
      if (0 == rc) {
        print "skip identical files: \"" s "\" and: \"" d "\""
      } else {
        print "copy updated file: \"" s "\" to: \"" d "\""
        if (0 != system("cp -p \"" s "\" \"" d "\"")) {
          print "***copy failed"
        }
      }
    } else {
      print "manually REMOVE file: \"" dst[f] "\""
    }
  }

  for (f in src) {
    s = src[f]
    print "manually COPY new file: \"" s "\""
  }
}

'
