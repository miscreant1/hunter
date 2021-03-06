-- Copyright (c) 2019-2020 Bartek thindil Jasicki <thindil@laeran.pl>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- ****h* Hunter/ActivateItems
-- FUNCTION
-- Provide code for open or execute selected files or directories.
-- SOURCE
package ActivateItems is
-- ****

   -- ****f* ActivateItems/CreateActivateUI
   -- FUNCTION
   -- Create activation UI
   -- SOURCE
   procedure CreateActivateUI;
   -- ****

   -- ****f* ActivateItems/StartOpenWith
   -- FUNCTION
   -- Show text entry to start opening selected file or directory with custom
   -- command.
   -- PARAMETERS
   -- Self - Gtk_Tool_Button clicked. Unused. Can be null
   -- SOURCE
--   procedure StartOpenWith(Self: access Gtk_Tool_Button_Record'Class);
--   -- ****
--
--   -- ****f* ActivateItems/OpenItemWith
--   -- FUNCTION
--   -- Open selected item or directory with entered by user command. That
--   -- command can have argumets either.
--   -- PARAMETERS
--   -- Self     - Text entry with command to use
--   -- Icon_Pos - Position of text entry icon which was pressed or if key
--   --            Enter was pressed, simulate pressing proper icon
--   -- SOURCE
--   procedure OpenItemWith
--     (Self: access Gtk_Entry_Record'Class; Icon_Pos: Gtk_Entry_Icon_Position);
--   -- ****
--
--   -- ****f* ActivateItems/ExecuteFile
--   -- FUNCTION
--   -- Execute selected file. That file must be graphical application or
--   -- all output will be redirected to terminal (invisible to user).
--   -- PARAMETERS
--   -- Self - Gtk_Tool_Button clicked. Unused. Can be null
--   -- SOURCE
--   procedure ExecuteFile(Self: access Gtk_Tool_Button_Record'Class);
--   -- ****
--

end ActivateItems;
