ress() {
    FILENAME=$1
    if [ $# -lt 1 ]; then
        echo "Usage: $0 FILENAME"
    else
        markdown $FILENAME | w3m -T text/html
    fi
}
