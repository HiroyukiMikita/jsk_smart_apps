#!/usr/bin/env python

import roslib,rospy;
import sys,yaml;

"""
if cameras.yaml or points.yaml is updated,
please run "./create_mux_launch.py" manually
to update cameras_and_points_mux.launch
"""

cameras_list_yaml = yaml.load(open('cameras.yaml').read());
points_list_yaml = yaml.load(open('points.yaml').read());
new_mux_file = open('cameras_and_points_mux.launch', 'w');

new_mux_file.write("<launch>");
new_mux_file.write("""
  <node pkg="topic_tools" type="mux" output="screen"
        name="mux_for_image" respawn="true"
        args="image_input_mux""");
for i in cameras_list_yaml['CameraList']:
    new_mux_file.write("\n");
    new_mux_file.write(cameras_list_yaml[i][0]);

new_mux_file.write(""" ">
    <remap from="mux" to="image_mux"/>
    <param name="lazy" value="true"/>
  </node>

  <node pkg="topic_tools" type="mux" output="screen"
        name="mux_for_camera_info" respawn="true"
        args="camera_info_input_mux""");
for i in cameras_list_yaml['CameraList']:
    new_mux_file.write("\n");
    new_mux_file.write(cameras_list_yaml[i][1]);
new_mux_file.write(""" ">
    <remap from="mux" to="camera_info_mux"/>
    <param name="lazy" value="true"/>
  </node>

  <node pkg="topic_tools" type="mux" output="screen"
        name="mux_for_points" respawn="true"
        args="points_input_mux""");
for i in points_list_yaml['points']:
    new_mux_file.write("\n");
    new_mux_file.write(i);
new_mux_file.write(""" ">
    <remap from="mux" to="points_mux"/>
    <param name="lazy" value="true"/>
  </node>""");
new_mux_file.write("\n");
new_mux_file.write("</launch>");
new_mux_file.truncate();
new_mux_file.close();
