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

with Ada.Directories; use Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.String_Split; use GNAT.String_Split;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
use Tcl.Tk.Ada.Widgets.Toplevel.MainWindow;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tk.Ada.Wm; use Tcl.Tk.Ada.Wm;
with LoadData; use LoadData;
with MainWindow; use MainWindow;
with Messages; use Messages;
with Preferences; use Preferences;
with RefreshData; use RefreshData;
with Utils; use Utils;
--with Ada.Strings.Fixed; use Ada.Strings.Fixed;
--with Toolbars; use Toolbars;

package body ActivateItems is

   package CreateCommands is new Tcl.Ada.Generic_Command(Integer);

   function Activate_Item_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;

      -- ****if* ActivateItems/Activate_Item_Command
      -- FUNCTION
      -- "Activate" selected file or directory. Action depends on what selected
      -- item is. For example: it go to selected directory, opens text files in
      -- editor and so on.
      -- PARAMETERS
      -- ClientData - Custom data send to the command. Unused
      -- Interp     - Tcl interpreter in which command was executed. Unused
      -- Argc       - Number of arguments passed to the command. Unused
      -- Argv       - Values of arguments passed to the command.
      -- SOURCE
   function Activate_Item_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
      -- ****
      DirectoryTree: Ttk_Tree_View;
      Tokens: Slice_Set;
      FileName: Unbounded_String;
   begin
      DirectoryTree.Interp := Interp;
      DirectoryTree.Name :=
        New_String(".mainframe.paned.directoryframe.directorytree");
      Create(Tokens, Selection(DirectoryTree), " ");
      FileName :=
        CurrentDirectory & '/' &
        ItemsList(Positive'Value(Slice(Tokens, 1))).Name;
      if Is_Directory(To_String(FileName)) then
         if not Is_Read_Accessible_File(To_String(FileName)) then
            ShowMessage("You can't enter this directory.");
            return TCL_OK;
         end if;
         if CurrentDirectory = To_Unbounded_String("/") then
            CurrentDirectory := Null_Unbounded_String;
         end if;
         CurrentDirectory := FileName;
         if Settings.ShowPreview then
            ItemsList := SecondItemsList;
            Wm_Set
              (Get_Main_Window(Get_Context), "title",
               "{Hunter " & To_String(CurrentDirectory) & "}");
         else
            LoadDirectory(To_String(CurrentDirectory));
         end if;
         UpdateDirectoryList(True);
         UpdateWatch(To_String(CurrentDirectory));
      else
         declare
            MimeType: constant String :=
              GetMimeType(Full_Name(To_String(FileName)));
            Pid: GNAT.OS_Lib.Process_Id;
            Openable: Boolean := CanBeOpened(MimeType);
            Arguments: constant Argument_List :=
              (new String'(To_String(FileName)), new String'(""));
            ExecutableName: constant String := FindExecutable("xdg-open");
         begin
            if MimeType(1 .. 4) = "text" and not Openable then
               Openable := CanBeOpened("text/plain");
            end if;
            if not Openable then
               if not Is_Executable_File(To_String(FileName)) then
                  ShowMessage
                    ("I can't open this file. No application associated with this type of files.");
                  return TCL_OK;
               end if;
               Pid :=
                 Non_Blocking_Spawn
                   (Full_Name(To_String(CurrentSelected)),
                    Argument_String_To_List("").all);
               if Pid = GNAT.OS_Lib.Invalid_Pid then
                  ShowMessage("I can't execute this file.");
               else
                  Lower(Get_Main_Window(Interp));
               end if;
            else
               if ExecutableName = "" then
                  return TCL_OK;
               end if;
               Pid :=
                 Non_Blocking_Spawn
                   (ExecutableName,
                    Arguments(Arguments'First .. Arguments'Last - 1));
            end if;
            if Pid = GNAT.OS_Lib.Invalid_Pid then
               ShowMessage
                 ("I can't open this file. Can't start application asociated with this type of files.");
            end if;
         end;
      end if;
      return TCL_OK;
   end Activate_Item_Command;

   procedure CreateActivateUI is
      procedure AddCommand
        (Name: String; AdaCommand: not null CreateCommands.Tcl_CmdProc) is
         Command: Tcl.Tcl_Command;
      begin
         Command :=
           CreateCommands.Tcl_CreateCommand
             (Get_Context, Name, AdaCommand, 0, null);
         if Command = null then
            raise Program_Error with "Can't add command " & Name;
         end if;
      end AddCommand;
   begin
      AddCommand("ActivateItem", Activate_Item_Command'Access);
   end CreateActivateUI;

--   -- ****if* ActivateItems/ActivateFileButton
--   -- FUNCTION
--   -- "Activate" selected file or directory. Action depends on what selected
--   -- item is. For example: it go to selected directory, opens text files in
--   -- editor and so on.
--   -- PARAMETERS
--   -- Self   - Gtk_Button which was pressed. Unused
--   -- SOURCE
--   procedure ActivateFileButton(Self: access Gtk_Tool_Button_Record'Class) is
--      pragma Unreferenced(Self);
--      -- ****
--   begin
--      ActivateFile
--        (DirectoryView, Gtk_Tree_Path_New, Get_Column(DirectoryView, 0));
--   end ActivateFileButton;
--
--   procedure StartOpenWith(Self: access Gtk_Tool_Button_Record'Class) is
--      pragma Unreferenced(Self);
--   begin
--      NewAction := OPENWITH;
--      Set_Icon_Tooltip_Text
--        (TextEntry, Gtk_Entry_Icon_Secondary,
--         Gettext("Enter command to use to open selected item."));
--      Set_Text(TextEntry, "");
--      Show_All(TextEntry);
--      Grab_Focus(TextEntry);
--   end StartOpenWith;
--
--   procedure OpenItemWith
--     (Self: access Gtk_Entry_Record'Class;
--      Icon_Pos: Gtk_Entry_Icon_Position) is
--      Command: GNAT.OS_Lib.String_Access;
--      Arguments: Argument_List(1 .. 3);
--      Pid: GNAT.OS_Lib.Process_Id;
--      CommandName, CommandArguments: Unbounded_String;
--      EnteredCommand: constant String := Get_Text(Self);
--   begin
--      if Icon_Pos = Gtk_Entry_Icon_Primary then
--         Set_Text(Self, "");
--         Hide(Gtk_Widget(Self));
--         return;
--      end if;
--      if Get_Text(Self) = "" then
--         return;
--      end if;
--      if Index(Get_Text(Self), " ") > 0 then
--         CommandName :=
--           To_Unbounded_String
--             (EnteredCommand(1 .. Index(EnteredCommand, " ") - 1));
--         CommandArguments :=
--           To_Unbounded_String
--             (EnteredCommand
--                (Index(EnteredCommand, " ") + 1 .. EnteredCommand'Length));
--      else
--         CommandName := To_Unbounded_String(EnteredCommand);
--         CommandArguments := Null_Unbounded_String;
--      end if;
--      Command := Locate_Exec_On_Path(To_String(CommandName));
--      if Command = null then
--         ShowMessage
--           (Gettext("Command ") & To_String(CommandName) &
--            Gettext(" does not exist."));
--         Set_Text(Self, "");
--         Hide(Gtk_Widget(Self));
--         return;
--      end if;
--      Arguments :=
--        (Command, new String'(To_String(CommandArguments)),
--         new String'(To_String(CurrentSelected)));
--      if CommandArguments /= Null_Unbounded_String then
--         Pid :=
--           Non_Blocking_Spawn
--             (Program_Name => Arguments(Arguments'First).all,
--              Args => Arguments(Arguments'First + 1 .. Arguments'Last));
--      else
--         Pid :=
--           Non_Blocking_Spawn
--             (Program_Name => Arguments(Arguments'First).all,
--              Args => Arguments(Arguments'First + 2 .. Arguments'Last));
--      end if;
--      if Pid = GNAT.OS_Lib.Invalid_Pid then
--         ShowMessage(Gettext("Can't start command: ") & Get_Text(Self));
--      end if;
--      Set_Text(Self, "");
--      Hide(Gtk_Widget(Self));
--      Free(Command);
--   end OpenItemWith;
--
--   procedure ExecuteFile(Self: access Gtk_Tool_Button_Record'Class) is
--      pragma Unreferenced(Self);
--      Pid: GNAT.OS_Lib.Process_Id;
--   begin
--      Pid :=
--        Non_Blocking_Spawn
--          (Full_Name(To_String(CurrentSelected)),
--           Argument_String_To_List("").all);
--      if Pid = GNAT.OS_Lib.Invalid_Pid then
--         ShowMessage(Gettext("I can't execute this file."));
--      end if;
--   end ExecuteFile;
--
--   procedure CreateActivateUI is
--   begin
--      On_Clicked
--        (Gtk_Tool_Button(Get_Nth_Item(ItemToolBar, 0)), ExecuteFile'Access);
--      On_Clicked
--        (Gtk_Tool_Button(Get_Nth_Item(ItemToolBar, 1)),
--         ActivateFileButton'Access);
--      On_Clicked
--        (Gtk_Tool_Button(Get_Nth_Item(ItemToolBar, 2)), StartOpenWith'Access);
--   end CreateActivateUI;

end ActivateItems;
