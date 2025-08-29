# Rofi-JSON

> English is not my first language

Simple script to generate rofi menus using JSON

## Table of Contents

- [Introduction](#introduction)
- [Dependencies](#dependencies)
- [Guide](#guide)
- [Notes](#notes)
- [To-Do](#to-do)

## Introduction

Ever wanted to create a bunch of rofi menus but taking care of many submenus and stuff looks tiring?

Well, this script aims to use JSON "config" files to take care of that.

## Dependencies

- `rofi` (Its a script to generate rofi menus, after all)
- `jq` (Since we're using JSON files, this is a must-have tool)

## Quickstart

Invoke the `rofi-json.sh` file on the examples:

```bash
bash rofi-json.sh examples/powermenu.json
bash rofi-json.sh examples/wlrandr.json
```

Commonly used menus can be stored in `~/.config/rofi/resources/`, for example:

```bash
mkdir -p ~/.config/rofi/resources/
cp examples/wlrandr.json ~/.config/rofi/resources/
```

These menus may be invoked with friendlier names, for example:

```bash
bash rofi-json.sh wlrandr
```

## Guide

Using the `wlrandr.json` file in the `examples` folder, we can have a general idea of how it works.

The main json files needs two options:

- `prompt`: Whatever is the name that appears in the menu
- `choices`: Array of the different elements in the menu

While that is enough for the main menu, the choices need extra elements:

- `name`: Text that appears when this is an option in the menu
- `type`: Type of the choice

Now, `type` can be 3 things:

- `submenu`: Indicates that choosing this option will give you a new menu (Requires it to have a `redirect` attribute or `prompt` and `choices` attributes)
- `item`: Indicates that this choice will run a specific command (Requires the `exec` attribute for said command to run)
- `subitem`: Not used in JSON at all, its a special item used in generated submenus.

What are "generated submenus" you say? Well, its defined when a `submenu` has the `generate` attribute.

The `generate` attribute allows us to create dynamic menus, so it requires the regular `prompt` attribute and the new `command` attribute.

- `command`: The command to be run for generating a menu *before* what appears in `choices`. It has to return a valid array (As in, readable by `jq`).

This way, we can retrieve that selection and use it later using `$1` which means: Replace that `$1` with the response from the first generated submenu.

Of course, that means that `$2` will use the response from the second generated submenu and so on.

This replacement not only takes place in the `prompt`, but also in the `exec` of the items.

But what if a submenu gets too large? Well, it can be splitted by using the `redirect` attribute instead of the `prompt` and `choices` attributes.

-`redirect`: Name of the resource file for the next submenu. It has to be a valid json menu (As in, it follows the same rules as the regular parent json menus, nothing special).

In the `wlrandr.json` example menu, you see it used when calling the `powermenu.json` example menu, which could also be used as a standalone menu.

## Notes

- As seen in the `powermenu.json` example menu, you can use icons if you write them down in the `name` attribute.

## To-Do

- `input` type
- PKGBUILD file
