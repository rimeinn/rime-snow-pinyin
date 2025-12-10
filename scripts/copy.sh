RIME_DIR="$HOME/.local/share/fcitx5/rime"

cp $RIME_DIR/snow_*.txt .
cp $RIME_DIR/snow_*.yaml .
cp $RIME_DIR/lua/snow/* lua/snow/
rm *.custom.yaml
