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

- <code>rofi</code> (Its a script to generate rofi menus, after all)
- <code>jq</code> (Since we're using JSON files, this is a must-have tool)

## Guide

Using the <code>wlrandr.json</code> file in the <code>examples</code> folder, we can have a general idea of how it works.

The main json files needs two options:

- <code>prompt</code>: Whatever is the name that appears in the menu
- <code>choices</code>: Array of the different elements in the menu

While that is enough for the main menu, the choices need extra elements:

- <code>name</code>: Text that appears when this is an option in the menu
- <code>type</code>: Type of the choice

Now, <code>type</code> can be 3 things:

- <code>submenu</code>: Indicates that choosing this option will give you a new menu (Requires it to have a <code>redirect</code> attribute or <code>prompt</code> and <code>choices</code> attributes)
- <code>item</code>: Indicates that this choice will run a specific command (Requires the <code>exec</code> attribute for said command to run)
- <code>subitem</code>: Not used in JSON at all, its a special item used in generated submenus.

What are "generated submenus" you say? Well, its defined when a <code>submenu</code> has the <code>generate</code> attribute.

The <code>generate</code> attribute allows us to create dynamic menus, so it requires the regular <code>prompt</code> attribute and the new <code>command</code> attribute.

- <code>command</code>: The command to be run for generating a menu *before* what appears in <code>choices</code>. It has to return a valid array (As in, readable by <code>jq</code>).

This way, we can retrieve that selection and use it later using <code>$1</code> which means: Replace that <code>$1</code> with the response from the first generated submenu.

Of course, that means that <code>$2</code> will use the response from the second generated submenu and so on.

This replacement not only takes place in the <code>prompt</code>, but also in the <code>exec</code> of the items.

But what if a submenu gets too large? Well, it can be splitted by using the <code>redirect</code> attribute instead of the <code>prompt</code> and <code>choices</code> attributes.

-<code>redirect</code>: Name of the resource file for the next submenu. It has to be a valid json menu (As in, it follows the same rules as the regular parent json menus, nothing special).

In the <code>wlrandr.json</code> example menu, you see it used when calling the <code>powermenu.json</code> example menu, which could also be used as a standalone menu.

## Notes

- As seen in the <code>powermenu.json</code> example menu, you can use icons if you write them down in the <code>name</code> attribute.

## To-Do

- <code>input</code> type
- PKGBUILD file
