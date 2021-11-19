#!/bin/sh

T_RELEASE="0.1.2" # also update in install.sh and libexec/t.rb

# check uncommitted changes

      if ! git diff-index --quiet HEAD --; then
        echo "There are files that need to be committed first."
      else
        # tag the release

              if git tag -a -m "Release $T_RELEASE" "$T_RELEASE"; then
                echo "Tagged $T_RELEASE release."

        # push the changes and tags

                if git push && git push --tags; then
                  echo "Pushed git commits and tags"
                else
                  echo "Release aborted."
                fi
              else
                echo "Release aborted."
              fi
      fi
