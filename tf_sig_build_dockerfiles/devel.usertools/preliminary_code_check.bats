changed_files() {
    git diff --name-only origin/master
    # get all changed targets...
    bazel query $(git diff --name-only origin/master | sed ':a; N; $!ba; s/\n/ union /g') --keep_going
}

setup_file() {
    cd /tf/tensorflow
    bazel version  # Start the bazel server
}

@test "Validate BUILD files" {
    changed_files | xargs bazel query | xargs bazel query "attr('srcs', '{}'
    bazel build --jobs=auto --nobuild -- //tensorflow/... -//tensorflow/lite/...
    bazel query --noimplicit_deps -- 'deps(//tensorflow/...) - kind("android_*", //tensorflow/...)' > /dev/null
}

@test "Check formatting for C++ files" {
    changed_files | grep -e '\.h$' -e '\.cc$' | xargs -I'{}' -n1 -P $(nproc --all) bash -c 'clang-format {} | diff - {} >/dev/null|| echo {}' | tee needs_help.txt
    test ! -s needs_help.txt
}

@test "Check formatting for Python files" {
    skip
    pylint --rcfile=tensorflow/tools/ci_build/pylintrc -j $(nproc --all) $(git ls-files '*.py') --disable=all --enable=E,W0311,W0312,C0330,C0301,C0326,W0611,W0622
}

@test "All tensorflow.org/code links point to real files" {
    for i in `grep -onI 'https://www.tensorflow.org/code/[a-zA-Z0-9/._-]\+' -r tensorflow`; do
        target=$(echo $i | sed 's!.*https://www.tensorflow.org/code/!!g')

        if [[ ! -f $target ]] && [[ ! -d $target ]]; then
            echo "$i" >> errors.txt
        fi
        if [[ -e errors.txt ]]; then
            echo "Broken links found:"
            cat errors.txt
            rm errors.txt
            false
        fi
    done
}

teardown_file() {
    bazel shutdown
}
