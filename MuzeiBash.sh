#!/usr/bin/env bash

######Initial stuff######
muzeiDir=~/Pictures/Muzei
mkdir -p $muzeiDir/Wallpaper
cd $muzeiDir

######Needed packages######
function notifytestLinux(){
  if ! [ "$(which notify-send)" ]
  then
    echo "Please install a notification server for a better experience."
  fi
}
function notifytestOSX(){
  if ! [ "$(which terminal-notifier)" ]
  then
    echo "Please install terminal-notifier for a better experience."
  fi
}
case "$OSTYPE" in
  linux* | *BSD*) notifytestLinux ;;
  darwin*)        notifytestOSX ;;
  *)              echo "Get a proper OS, kid." && exit ;;
esac
if ! [ "$(which jq)" ]
then
  echo "You need jq to use this."
  exit
fi

######Checking for updates (checkMuzei.sh in older versions)######
if ! [ -f ./muzeich.json ]
then
  curl -o muzeich.json 'https://muzeiapi.appspot.com/featured?cachebust=1'
else
  curl -o muzeich2.json 'https://muzeiapi.appspot.com/featured?cachebust=1'
  if [ "$(cmp muzeich.json muzeich2.json)" ]
  then
    mv muzeich2.json muzeich.json
  else
    rm muzeich2.json
    echo "No wallpaper update. Exiting."
    exit
  fi
fi

######Deleting old .xinitrc line for feh/hsetroot/nitrogen if it exists######
if [ -f ~/.xinitrc ]
then
  echo "Deleting old .xinitrc line..."
  if [ "$(cat ~/.xinitrc | grep '^hsetroot -cover')" ]
  then
    sed -i "/^hsetroot -cover/d" ~/.xinitrc
  elif [ "$(cat ~/.xinitrc | grep '^sh ~/.fehbg')" ]
  then
    sed -i "/^sh ~\/.fehbg/d" ~/.xinitrc
  elif [ "$(cat ~/.xinitrc | grep '^nitrogen --restore')" ]
  then
    sed -i "/^nitrogen --restore/d" ~/.xinitrc
  fi
fi

######Parse the Muzei JSON######
imageUri=`jq '.imageUri' $muzeiDir/muzeich.json | sed s/\"//g`
imageFile=`basename $imageUri`
title=`jq '.title' $muzeiDir/muzeich.json | sed s/\"//g`
byline=`jq '.byline' $muzeiDir/muzeich.json | sed s/\"//g`

######Clean up old wallpapers######
cd Wallpaper
echo "Cleaning up old files..."
rm *

######Get the latest wallpaper######
if [ -f $imageFile ]
then
  echo "File $imageFile exists."
else
  echo "File $imageFile does not exist, downloading..."
  curl -O $imageUri
fi

######Functions for autostarting feh, hsetroot and nitrogen######
function feh_xinitSet(){
  if ! [ -f ~/.xinitrc ] || ! [ "$(cat ~/.xinitrc | grep ^exec)" ]
  then
    echo "sh ~/.fehbg &" >> ~/.xinitrc
  else
    sed -i "s#^exec #sh ~/.fehbg \&\nexec #" ~/.xinitrc
  fi
}
function hsetroot_xinitSet(){
  if ! [ -f ~/.xinitrc ] || ! [ "$(cat ~/.xinitrc | grep ^exec)" ]
  then
    echo "hsetroot -cover $muzeiDir/Wallpaper/$imageFile &" >> ~/.xinitrc
  else
    sed -i "s#^exec #hsetroot -cover $muzeiDir/Wallpaper/$imageFile \&\nexec #" ~/.xinitrc
  fi
}
function nitrogen_xinitSet(){
  if ! [ -f ~/.xinitrc ] || ! [ "$(cat ~/.xinitrc | grep ^exec)" ]
  then
    echo "nitrogen --restore &" >> ~/.xinitrc
  else
    sed -i "s#^exec #nitrogen --restore \&\nexec #" ~/.xinitrc
  fi
}

######Set the wallpaper######
function setWallpaperLinux(){
  if [ "$(pidof gnome-settings-daemon)" ]
  then
    echo "Gnome-settings-daemons detected, setting wallpaper with gsettings..."
    gsettings set org.gnome.desktop.background picture-uri file://$muzeiDir/Wallpaper/$imageFile
  else
    if [ "$(which feh)" ]
    then
      echo "Gnome-settings-daemons not running, setting wallpaper with feh..."
      feh $imageFile
      feh_xinitSet
    elif [ "$(which hsetroot)" ]
    then
      echo "Gnome-settings-daemons not running, setting wallpaper with hsetroot..."
      hsetroot -cover $imageFile
      hsetroot_xinitSet
    elif [ "$(which nitrogen)" ]
    then
      echo "Gnome-settings-daemons not running, setting wallpaper with nitrogen..."
      nitrogen $imageFile
      nitrogen_xinitSet
    else
      echo "You need to have either feh, hsetroot or nitrogen, bruhbruh."
      exit
    fi
  fi
}
function setWallpaperOSX(){
  defaults write com.apple.desktop Background "{default = {ImageFilePath='$muzeiDir/Wallpaper/$imageFile'; };}"
  killall Dock
#  osascript
#  tell application "Finder"
#    set desktop picture to file "$muzeiDir/Wallpaper/$imageFile"
#  end tell
}
case "$OSTYPE" in
  linux* | *BSD*) setWallpaperLinux ;;
  darwin*)        setWallpaperOSX ;;
esac

######Send a notification######
cd $muzeiDir
if [ -f MuzeiLogo.png ];
then
  echo "Logo already exists."
else
  echo "Logo doesn't exist, downloading..."
  curl -O "https://raw.github.com/Feminist-Software-Foundation/Muzei-Bash/master/MuzeiLogo.png"
fi
case "$OSTYPE" in
  linux* | *BSD*) notify-send "New wallpaper: '$title'" "$byline" -i $muzeiDir/MuzeiLogo.png ;;
  darwin*)        terminal-notifier -title "Muzei-Bash" -message "New wallpaper: '$title'" "$byline" ;;
esac
