#!/bin/zsh

konsole &
konsole_pid=$!
 
sleep 0.5 
 
qdbus org.kde.konsole-$konsole_pid /konsole/MainWindow_1 org.kde.KMainWindow.activateAction split-view-left-right
qdbus org.kde.konsole-$konsole_pid /Sessions/1 org.kde.konsole.Session.runCommand "ssh ${host1}"
qdbus org.kde.konsole-$konsole_pid /konsole/MainWindow_1 org.kde.KMainWindow.activateAction split-view-top-bottom
qdbus org.kde.konsole-$konsole_pid /Sessions/2 org.kde.konsole.Session.runCommand "ssh ${host2}"
qdbus org.kde.konsole-$konsole_pid /Windows/1 org.kde.konsole.Window.setCurrentSession 1
qdbus org.kde.konsole-$konsole_pid /Sessions/3 org.kde.konsole.Session.runCommand "ssh ${host3}"
qdbus org.kde.konsole-$konsole_pid /konsole/MainWindow_1 org.kde.KMainWindow.activateAction split-view-top-bottom
qdbus org.kde.konsole-$konsole_pid /Sessions/4 org.kde.konsole.Session.runCommand "ssh ${host4}"
