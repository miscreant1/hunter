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

-- ****h* Hunter/DeleteItems
-- FUNCTION
-- Provide code to delete files and directories
-- SOURCE
package DeleteItems is
-- ****

   -- ****f* DeleteItems/DeleteSelected
   -- FUNCTION
   -- Delete selected files and directories
   -- RESULT
   -- True if current directory was deleted too, otherwise false
   -- SOURCE
   function DeleteSelected return Boolean;
   -- ****

   -- ****f* DeleteItems/DeleteItem
   -- FUNCTION
   -- Show message to start deleting selected files and directories.
   -- PARAMETERS
   -- Self - Gtk_Tool_Button which was clicked. Unused.
   -- SOURCE
--   procedure DeleteItem(Self: access Gtk_Tool_Button_Record'Class);
   -- ****

end DeleteItems;
