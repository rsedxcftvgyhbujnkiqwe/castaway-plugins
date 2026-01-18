# Contributing

Edit data.json then

```bash
python3 genhtml.py > reverts.html
```

Make sure to use the name of the item on the tf2wiki page when you click the thumbnail. For instance:

`https://wiki.teamfortress.com/wiki/Blutsauger#/media/File:Backpack_Blutsauger.png`

When you set the png for the backpack_image on the Blutsauger you put `Backpack_Blutsauger.png`

For anything with weird html stuff in the name use that code, for instance `Backpack_Chargin%27_Targe.png`

Push changes to both data.json and reverts.html