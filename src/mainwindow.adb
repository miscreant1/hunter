-- Copyright (c) 2019 Bartek thindil Jasicki <thindil@laeran.pl>
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

with Ada.Calendar.Formatting;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Directories; use Ada.Directories;
with Ada.Environment_Variables; use Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Text_IO; use Ada.Text_IO;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.Expect; use GNAT.Expect;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.String_Split; use GNAT.String_Split;
with Gtk.Accel_Map; use Gtk.Accel_Map;
with Gtk.Button; use Gtk.Button;
with Gtk.Container; use Gtk.Container;
with Gtk.Info_Bar; use Gtk.Info_Bar;
with Gtk.Image; use Gtk.Image;
with Gtk.Label; use Gtk.Label;
with Gtk.List_Store; use Gtk.List_Store;
with Gtk.Main; use Gtk.Main;
with Gtk.Menu_Tool_Button; use Gtk.Menu_Tool_Button;
with Gtk.Message_Dialog; use Gtk.Message_Dialog;
with Gtk.Paned; use Gtk.Paned;
with Gtk.Radio_Tool_Button; use Gtk.Radio_Tool_Button;
with Gtk.Toggle_Button; use Gtk.Toggle_Button;
with Gtk.Stack; use Gtk.Stack;
with Gtk.Text_Buffer; use Gtk.Text_Buffer;
with Gtk.Text_Iter; use Gtk.Text_Iter;
with Gtk.Text_View; use Gtk.Text_View;
with Gtk.Tree_Model; use Gtk.Tree_Model;
with Gtk.Tree_Model_Filter; use Gtk.Tree_Model_Filter;
with Gtk.Tree_Selection; use Gtk.Tree_Selection;
with Gtk.Tree_View; use Gtk.Tree_View;
with Gtk.Widget; use Gtk.Widget;
with Glib; use Glib;
with Glib.Object; use Glib.Object;
with Gdk.Types.Keysyms; use Gdk.Types.Keysyms;
with Bookmarks; use Bookmarks;
with CopyItems; use CopyItems;
with CreateItems; use CreateItems;
with ErrorDialog; use ErrorDialog;
with LoadData; use LoadData;
with Messages; use Messages;
with MoveItems; use MoveItems;
with SearchItems; use SearchItems;
with Utils; use Utils;

package body MainWindow is

   -- ****iv* MainWindow/DesktopFile
   -- FUNCTION
   -- Name of .desktop file or name of application associated with selected
   -- file.
   -- SOURCE
   DesktopFile: Unbounded_String;
   -- ****

   procedure Quit(Object: access Gtkada_Builder_Record'Class) is
   begin
      Unref(Object);
      Main_Quit;
   end Quit;

   -- ****if* MainWindow/GetSelectedItems
   -- FUNCTION
   -- Add selected file or directory to SelectedItems list.
   -- PARAMETERS
   -- Model - Gtk_Tree_Model with content of currently selected directory
   -- Path  - Gtk_Tree_Path to selected element in Model
   -- Iter  - Gtk_Tree_Iter to selected element in Model
   -- SOURCE
   procedure GetSelectedItems(Model: Gtk_Tree_Model; Path: Gtk_Tree_Path;
      Iter: Gtk_Tree_Iter) is
      pragma Unreferenced(Path);
      -- ****
   begin
      if CurrentDirectory = To_Unbounded_String("/") then
         CurrentDirectory := Null_Unbounded_String;
      end if;
      SelectedItems.Append
        (CurrentDirectory &
         To_Unbounded_String("/" & Get_String(Model, Iter, 0)));
   end GetSelectedItems;

   -- ****if* MainWindow/FindFileName
   -- FUNCTION
   -- Find name of associated program with selected file. If found, replace
   -- .desktop file name with name of application.
   -- PARAMETERS
   -- Model - Gtk_Tree_Model with content of currently selected directory
   -- Path  - Gtk_Tree_Path to selected element in Model
   -- Iter  - Gtk_Tree_Iter to selected element in Model
   -- SOURCE
   function FindFileName(Model: Gtk_Tree_Model; Path: Gtk_Tree_Path;
      Iter: Gtk_Tree_Iter) return Boolean is
      pragma Unreferenced(Path);
      -- ****
   begin
      if Get_String(Model, Iter, 1) = To_String(DesktopFile) then
         DesktopFile := To_Unbounded_String(Get_String(Model, Iter, 0));
         return True;
      end if;
      return False;
   end FindFileName;

   -- ****if* MainWindow/ShowItemInfo
   -- FUNCTION
   -- Show detailed information (name, size, modification date, etc) about
   -- selected file or directory.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure ShowItemInfo(Object: access Gtkada_Builder_Record'Class) is
      -- ****
      Amount: Natural := 0;
      Directory: Dir_Type;
      Last: Natural;
      FileName: String(1 .. 1024);
      SelectedPath: constant String := Full_Name(To_String(CurrentSelected));
      ObjectsNames: constant array(Positive range <>) of Unbounded_String :=
        (To_Unbounded_String("lblfiletype"),
         To_Unbounded_String("lblfiletype2"),
         To_Unbounded_String("btnprogram"), To_Unbounded_String("lblprogram2"),
         To_Unbounded_String("cbtnownerexecute"));
   begin
      Set_Label(Gtk_Label(Get_Object(Object, "lblname")), SelectedPath);
      Set_Label(Gtk_Label(Get_Object(Object, "lblsize2")), "Size:");
      for Name of ObjectsNames loop
         Hide(Gtk_Widget(Get_Object(Object, To_String(Name))));
      end loop;
      if Is_Regular_File(SelectedPath) then
         for Name of ObjectsNames loop
            Show_All(Gtk_Widget(Get_Object(Object, To_String(Name))));
         end loop;
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblsize")),
            CountFileSize(Size(SelectedPath)));
         Set_Label
           (Gtk_Label(Get_Object(Object, "lbllastmodified")),
            Ada.Calendar.Formatting.Image(Modification_Time(SelectedPath)));
         Set_Label
           (Gtk_Label(Get_Object(Object, "lblfiletype")),
            GetMimeType(SelectedPath));
         if not CanBeOpened(GetMimeType(SelectedPath)) then
            Set_Label(Gtk_Button(Get_Object(Object, "btnprogram")), "none");
         else
            declare
               ProcessDesc: Process_Descriptor;
               Result: Expect_Match;
            begin
               Non_Blocking_Spawn
                 (ProcessDesc,
                  Containing_Directory(Command_Name) & "/xdg-mime",
                  Argument_String_To_List
                    ("query default " & GetMimeType(SelectedPath)).all);
               Expect(ProcessDesc, Result, Regexp => ".+", Timeout => 1_000);
               if Result = 1 then
                  DesktopFile :=
                    To_Unbounded_String(Expect_Out_Match(ProcessDesc));
                  Foreach
                    (Gtk_List_Store(Get_Object(Object, "applicationsstore")),
                     FindFileName'Access);
                  if Index(DesktopFile, ".desktop") = 0 then
                     Set_Label
                       (Gtk_Button(Get_Object(Object, "btnprogram")),
                        To_String(DesktopFile));
                  else
                     Set_Label
                       (Gtk_Label(Get_Object(Object, "lblprogram")),
                        To_String(DesktopFile) & " (not installed)");
                  end if;
               end if;
               Close(ProcessDesc);
            end;
         end if;
      elsif Is_Directory(SelectedPath) then
         Set_Label(Gtk_Label(Get_Object(Object, "lblsize2")), "Elements:");
         if Is_Read_Accessible_File(SelectedPath) then
            Open(Directory, SelectedPath);
            loop
               Read(Directory, FileName, Last);
               exit when Last = 0;
               Amount := Amount + 1;
            end loop;
            Close(Directory);
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblsize")),
               Natural'Image(Amount - 2));
         else
            Set_Label(Gtk_Label(Get_Object(Object, "lblsize")), "Unknown");
         end if;
         Set_Label
           (Gtk_Label(Get_Object(Object, "lbllastmodified")),
            Ada.Calendar.Formatting.Image(Modification_Time(SelectedPath)));
      else
         Set_Label(Gtk_Label(Get_Object(Object, "lblsize")), "Unknown");
      end if;
      declare
         ProcessDesc: Process_Descriptor;
         Result: Expect_Match;
         FileStats: Unbounded_String;
         Tokens: Slice_Set;
      begin
         Non_Blocking_Spawn
           (ProcessDesc, "stat",
            Argument_String_To_List("-c""%A %U %G"" " & To_String(CurrentSelected)).all);
         Expect(ProcessDesc, Result, Regexp => ".+", Timeout => 1_000);
         if Result = 1 then
            FileStats := To_Unbounded_String(Expect_Out_Match(ProcessDesc));
            Create(Tokens, To_String(FileStats), " ");
            if Slice(Tokens, 1)(3) = '-' then
               Set_Active
                 (Gtk_Toggle_Button(Get_Object(Object, "cbtnownerread")),
                  False);
            else
               Set_Active
                 (Gtk_Toggle_Button(Get_Object(Object, "cbtnownerread")),
                  True);
            end if;
            if Slice(Tokens, 1)(4) = '-' then
               Set_Active
                 (Gtk_Toggle_Button(Get_Object(Object, "cbtnownerwrite")),
                  False);
            else
               Set_Active
                 (Gtk_Toggle_Button(Get_Object(Object, "cbtnownerwrite")),
                  True);
            end if;
            Set_Label
              (Gtk_Label(Get_Object(Object, "lblowner")), Slice(Tokens, 2));
            if Slice(Tokens, 1)(5) = '-' then
               Set_Active
                 (Gtk_Toggle_Button(Get_Object(Object, "cbtnownerexecute")),
                  False);
            else
               Set_Active
                 (Gtk_Toggle_Button(Get_Object(Object, "cbtnownerexecute")),
                  True);
            end if;
         end if;
         Close(ProcessDesc);
      end;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "infostack")), "info");
   end ShowItemInfo;

   -- ****if* MainWindow/PreviewItem
   -- FUNCTION
   -- Preview selected file or directory. If preview is not available, show
   -- info about selected file or directory.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure PreviewItem(Object: access Gtkada_Builder_Record'Class) is
   -- ****
   begin
      if Setting then
         return;
      end if;
      if Is_Directory(To_String(CurrentSelected)) then
         Show_All(Gtk_Widget(Get_Object(Object, "scrolllist")));
         Hide(Gtk_Widget(Get_Object(Object, "scrolltext")));
         Hide(Gtk_Widget(Get_Object(Object, "scrollimage")));
         Hide(Gtk_Widget(Get_Object(Object, "btnrun")));
         LoadDirectory(To_String(CurrentSelected), "fileslist1");
      else
         Show_All(Gtk_Widget(Get_Object(Object, "scrolltext")));
         Hide(Gtk_Widget(Get_Object(Object, "scrolllist")));
         Hide(Gtk_Widget(Get_Object(Object, "scrollimage")));
         declare
            MimeType: constant String :=
              GetMimeType(To_String(CurrentSelected));
            Buffer: constant Gtk_Text_Buffer :=
              Get_Buffer(Gtk_Text_View(Get_Object(Object, "filetextview")));
            Iter: Gtk_Text_Iter;
            File: File_Type;
         begin
            Set_Text(Buffer, "");
            Get_Start_Iter(Buffer, Iter);
            if not Is_Executable_File(To_String(CurrentSelected)) then
               Hide(Gtk_Widget(Get_Object(Builder, "btnrun")));
            end if;
            if MimeType(1 .. 4) = "text" then
               Open(File, In_File, To_String(CurrentSelected));
               while not End_Of_File(File) loop
                  Insert(Buffer, Iter, Get_Line(File) & LF);
               end loop;
               Close(File);
            elsif MimeType(1 .. 5) = "image" then
               Hide(Gtk_Widget(Get_Object(Object, "scrolltext")));
               Set
                 (Gtk_Image(Get_Object(Object, "imgpreview")),
                  To_String(CurrentSelected));
               Show_All(Gtk_Widget(Get_Object(Object, "scrollimage")));
            else
               Hide(Gtk_Widget(Get_Object(Object, "btnpreview")));
               if not CanBeOpened(MimeType) then
                  Hide(Gtk_Widget(Get_Object(Object, "btnopen")));
               end if;
               Setting := True;
               Set_Active
                 (Gtk_Radio_Tool_Button(Get_Object(Object, "btnfileinfo")),
                  True);
               Setting := False;
               return;
            end if;
         end;
      end if;
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "infostack")), "preview");
   end PreviewItem;

   -- ****if* MainWindow/ShowItem
   -- FUNCTION
   -- Show info about selected item or preview it.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure ShowItem(Object: access Gtkada_Builder_Record'Class) is
   -- ****
   begin
      if Setting then
         return;
      end if;
      SelectedItems.Clear;
      Selected_Foreach
        (Gtk.Tree_View.Get_Selection
           (Gtk_Tree_View(Get_Object(Object, "treefiles"))),
         GetSelectedItems'Access);
      if SelectedItems.Length /= 1 then
         Hide(Gtk_Widget(Get_Object(Object, "scrolltext")));
         Hide(Gtk_Widget(Get_Object(Object, "scrolllist")));
         Hide(Gtk_Widget(Get_Object(Object, "itemtoolbar")));
         return;
      end if;
      if CurrentSelected = SelectedItems(1) then
         return;
      end if;
      CurrentSelected := SelectedItems(1);
      Show_All(Gtk_Widget(Get_Object(Object, "itemtoolbar")));
      Set_Active
        (Gtk_Radio_Tool_Button(Get_Object(Object, "btnpreview")), True);
      PreviewItem(Object);
   end ShowItem;

   -- ****if* MainWindow/ActivateFile
   -- FUNCTION
   -- "Activate" selected file or directory. Action depends on what selected
   -- item is. For example: it go to selected directory, opens text files in
   -- editor and so on.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure ActivateFile(Object: access Gtkada_Builder_Record'Class) is
   -- ****
   begin
      if Is_Directory(To_String(CurrentSelected)) then
         if not Is_Read_Accessible_File(To_String(CurrentSelected)) then
            ShowMessage("You can't enter this directory.");
            return;
         end if;
         if CurrentDirectory = To_Unbounded_String("/") then
            CurrentDirectory := Null_Unbounded_String;
         end if;
         CurrentDirectory := CurrentSelected;
         LoadDirectory(To_String(CurrentDirectory), "fileslist");
         Set_Cursor
           (Gtk_Tree_View(Get_Object(Object, "treefiles")),
            Gtk_Tree_Path_New_From_String("0"), null, False);
         Grab_Focus(Gtk_Widget(Get_Object(Object, "treefiles")));
      else
         declare
            MimeType: constant String :=
              GetMimeType(To_String(CurrentSelected));
            Pid: GNAT.OS_Lib.Process_Id;
            Openable: Boolean := CanBeOpened(MimeType);
         begin
            if MimeType(1 .. 4) = "text" and not Openable then
               Openable := CanBeOpened("text/plain");
            end if;
            if not Openable then
               ShowMessage
                 ("I can't open this file. No application associated with this type of files.");
               return;
            else
               Pid :=
                 Non_Blocking_Spawn
                   (Containing_Directory(Command_Name) & "/xdg-open",
                    Argument_String_To_List(To_String(CurrentSelected)).all);
            end if;
            if Pid = GNAT.Os_Lib.Invalid_Pid then
               ShowMessage
                 ("I can't open this file. Can't start application asociated with this type of files.");
            end if;
         end;
      end if;
   end ActivateFile;

   procedure Reload(Object: access Gtkada_Builder_Record'Class) is
   begin
      LoadDirectory(To_String(CurrentDirectory), "fileslist");
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Object, "treefiles")),
         Gtk_Tree_Path_New_From_String("0"), null, False);
      Grab_Focus(Gtk_Widget(Get_Object(Object, "treefiles")));
      PreviewItem(Object);
   end Reload;

   -- ****if* MainWindow/DeleteItem
   -- FUNCTION
   -- Show message to start deleting selected files and directories.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure DeleteItem(Object: access Gtkada_Builder_Record'Class) is
      pragma Unreferenced(Object);
      -- ****
      Message: Unbounded_String := To_Unbounded_String("Delete?" & LF);
   begin
      for I in SelectedItems.First_Index .. SelectedItems.Last_Index loop
         Append(Message, SelectedItems(I));
         if Is_Directory(To_String(SelectedItems(I))) then
            Append(Message, "(and its content)");
         end if;
         if I /= SelectedItems.Last_Index then
            Append(Message, LF);
         end if;
      end loop;
      NewAction := DELETE;
      ShowMessage(To_String(Message), MESSAGE_QUESTION);
   end DeleteItem;

   -- ****if* MainWindow/StartRename
   -- FUNCTION
   -- Show text entry to start renaming selected file or directory and fill it
   -- with current element name.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure StartRename(Object: access Gtkada_Builder_Record'Class) is
      -- ****
      GEntry: constant Gtk_Widget := Gtk_Widget(Get_Object(Object, "entry"));
   begin
      NewAction := RENAME;
      if Is_Directory(To_String(CurrentSelected)) then
         Set_Icon_Tooltip_Text
           (Gtk_GEntry(GEntry), Gtk_Entry_Icon_Secondary, "Rename directory.");
      else
         Set_Icon_Tooltip_Text
           (Gtk_GEntry(GEntry), Gtk_Entry_Icon_Secondary, "Rename file.");
      end if;
      Set_Text(Gtk_GEntry(GEntry), Simple_Name(To_String(CurrentSelected)));
      Show_All(GEntry);
      Grab_Focus(GEntry);
   end StartRename;

   -- ****if* MainWindow/StartOpenWith
   -- FUNCTION
   -- Show text entry to start opening selected file or directory with custom
   -- command.
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI
   -- SOURCE
   procedure StartOpenWith(Object: access Gtkada_Builder_Record'Class) is
      -- ****
      GEntry: constant Gtk_Widget := Gtk_Widget(Get_Object(Object, "entry"));
   begin
      NewAction := OPENWITH;
      Set_Icon_Tooltip_Text
        (Gtk_GEntry(GEntry), Gtk_Entry_Icon_Secondary,
         "Enter command to use to open selected item.");
      Set_Text(Gtk_GEntry(GEntry), "");
      Show_All(GEntry);
      Grab_Focus(GEntry);
   end StartOpenWith;

   procedure OpenItemWith(Self: access Gtk_Entry_Record'Class;
      Icon_Pos: Gtk_Entry_Icon_Position) is
      Command: GNAT.OS_Lib.String_Access;
      Arguments: Argument_List_Access;
      Pid: GNAT.OS_Lib.Process_Id;
      CommandName, CommandArguments: Unbounded_String;
      EnteredCommand: constant String := Get_Text(Self);
   begin
      if Icon_Pos = Gtk_Entry_Icon_Primary then
         Set_Text(Self, "");
         Hide(Gtk_Widget(Self));
         return;
      end if;
      if Get_Text(Self) = "" then
         return;
      end if;
      if Index(Get_Text(Self), " ") > 0 then
         CommandName :=
           To_Unbounded_String
             (EnteredCommand(1 .. Index(EnteredCommand, " ") - 1));
         CommandArguments :=
           To_Unbounded_String
             (EnteredCommand
                (Index(EnteredCommand, " ") + 1 .. EnteredCommand'Length));
      else
         CommandName := To_Unbounded_String(EnteredCommand);
         CommandArguments := Null_Unbounded_String;
      end if;
      Command := Locate_Exec_On_Path(To_String(CommandName));
      if Command = null then
         ShowMessage("Command " & To_String(CommandName) & " does not exist.");
         Set_Text(Self, "");
         Hide(Gtk_Widget(Self));
         return;
      end if;
      Arguments :=
        Argument_String_To_List
          (Command.all & " " & To_String(CommandArguments) & " " &
           To_String(CurrentSelected));
      Free(Command);
      Pid :=
        Non_Blocking_Spawn
          (Program_Name => Arguments(Arguments'First).all,
           Args => Arguments(Arguments'First + 1 .. Arguments'Last));
      Free(Arguments);
      if Pid = GNAT.OS_Lib.Invalid_Pid then
         ShowMessage("Can't start command: " & Get_Text(Self));
      end if;
      Set_Text(Self, "");
      Hide(Gtk_Widget(Self));
   end OpenItemWith;

   -- ****if* MainWindow/ExecuteFile
   -- FUNCTION
   -- Execute selected file. That file must be graphical application or
   -- all output will be redirected to terminal (invisible to user).
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI (unused)
   -- SOURCE
   procedure ExecuteFile(Object: access Gtkada_Builder_Record'Class) is
      -- ****
      pragma Unreferenced(Object);
      Pid: GNAT.OS_Lib.Process_Id;
   begin
      Pid :=
        Non_Blocking_Spawn
          (To_String(CurrentSelected), Argument_String_To_List("").all);
      if Pid = GNAT.Os_Lib.Invalid_Pid then
         ShowMessage("I can't execute this file.");
      end if;
   end ExecuteFile;

   -- ****if* MainWindow/ShowAssociated
   -- FUNCTION
   -- Show setting for associating program for selected file
   -- PARAMETERS
   -- Object - GtkAda Builder used to create UI (unused)
   -- SOURCE
   procedure ShowAssociated(Object: access Gtkada_Builder_Record'Class) is
   -- ****
   begin
      Foreach(Gtk_Container(Get_Object(Object, "toolbar")), HideButton'Access);
      Hide(Gtk_Widget(Get_Object(Object, "boxpath")));
      Set_Label
        (Gtk_Label(Get_Object(Object, "lblcurrentassoc")),
         "Currenlty used program: " &
         Get_Label(Gtk_Button(Get_Object(Object, "btnprogram"))));
      Show_All(Gtk_Widget(Get_Object(Object, "btntoolapply")));
      Show_All(Gtk_Widget(Get_Object(Object, "btntoolcancel")));
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Object, "filestack")), "associated");
   end ShowAssociated;

   -- ****if* MainWindow/ShowFiles
   -- FUNCTION
   -- Back to files listing and preview/info
   -- PARAMETERS
   -- User_Data - Which button was clicked
   -- SOURCE
   procedure ShowFiles(User_Data: access GObject_Record'Class) is
      -- ****
      Pid: GNAT.OS_Lib.Process_Id;
      ProgramIter: Gtk_Tree_Iter;
      ProgramModel: Gtk_Tree_Model;
   begin
      Show_All(Gtk_Widget(Get_Object(Builder, "toolbar")));
      Show_All(Gtk_Widget(Get_Object(Builder, "boxpath")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolapply")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolcancel")));
      if User_Data = Get_Object(Builder, "btntoolapply") and
        Get_Visible_Child_Name(Gtk_Stack(Get_Object(Builder, "filestack"))) =
          "associated" then
         Get_Selected
           (Gtk.Tree_View.Get_Selection
              (Gtk_Tree_View(Get_Object(Builder, "treeprograms"))),
            ProgramModel, ProgramIter);
         if ProgramIter /= Null_Iter then
            Pid :=
              Non_Blocking_Spawn
                (Containing_Directory(Command_Name) & "/xdg-mime",
                 Argument_String_To_List
                   ("default " & Get_String(ProgramModel, ProgramIter, 1) &
                    " " & GetMimeType(To_String(CurrentSelected))).all);
            if Pid = GNAT.Os_Lib.Invalid_Pid then
               ShowMessage("I can't set new associated file.");
            end if;
         end if;
      end if;
      Reload(Builder);
      Set_Visible_Child_Name
        (Gtk_Stack(Get_Object(Builder, "filestack")), "files");
   end ShowFiles;

   procedure CreateMainWindow(NewBuilder: Gtkada_Builder; Directory: String) is
   begin
      Builder := NewBuilder;
      Register_Handler(Builder, "Main_Quit", Quit'Access);
      Register_Handler(Builder, "Show_Item", ShowItem'Access);
      Register_Handler(Builder, "Activate_File", ActivateFile'Access);
      Register_Handler(Builder, "Toggle_Search", ToggleSearch'Access);
      Register_Handler(Builder, "Search_Files", SearchFiles'Access);
      Register_Handler(Builder, "Add_New", AddNew'Access);
      Register_Handler(Builder, "Delete_Item", DeleteItem'Access);
      Register_Handler(Builder, "Create_New", CreateNew'Access);
      Register_Handler(Builder, "Start_Rename", StartRename'Access);
      Register_Handler(Builder, "Move_Items", MoveData'Access);
      Register_Handler(Builder, "Copy_Items", CopyData'Access);
      Register_Handler(Builder, "Go_Home", GoHome'Access);
      Register_Handler(Builder, "Hide_Message", HideMessage'Access);
      Register_Handler(Builder, "Set_Response", SetResponse'Access);
      Register_Handler(Builder, "Start_Open_With", StartOpenWith'Access);
      Register_Handler(Builder, "Execute_File", ExecuteFile'Access);
      Register_Handler(Builder, "Preview_Item", PreviewItem'Access);
      Register_Handler(Builder, "Show_Item_Info", ShowItemInfo'Access);
      Register_Handler(Builder, "Show_Associated", ShowAssociated'Access);
      Register_Handler(Builder, "Show_Files", ShowFiles'Access);
      Register_Handler
        (Builder, "Create_Bookmark_Menu", CreateBookmarkMenu'Access);
      Do_Connect(Builder);
      Set_Visible_Func
        (Gtk_Tree_Model_Filter(Get_Object(Builder, "filesfilter")),
         VisibleFiles'Access);
      On_Icon_Press
        (Gtk_GEntry(Get_Object(Builder, "entry")), IconPressed'Access);
      On_Response
        (Gtk_Info_Bar(Get_Object(Builder, "actioninfo")),
         MessageResponse'Access);
      Add_Entry("<mainwindow>/reload", GDK_LC_r, 8);
      Add_Entry("<mainwindow>/goup", GDK_LC_u, 8);
      Add_Entry("<mainwindow>/path1", GDK_1, 8);
      Add_Entry("<mainwindow>/path2", GDK_2, 8);
      Add_Entry("<mainwindow>/path3", GDK_3, 8);
      Add_Entry("<mainwindow>/path4", GDK_4, 8);
      Add_Entry("<mainwindow>/path5", GDK_5, 8);
      Add_Entry("<mainwindow>/path6", GDK_6, 8);
      Add_Entry("<mainwindow>/path7", GDK_7, 8);
      Add_Entry("<mainwindow>/path8", GDK_9, 8);
      Add_Entry("<mainwindow>/path9", GDK_9, 8);
      if Ada.Directories.Exists(Directory) then
         CurrentDirectory := To_Unbounded_String(Directory);
      else
         CurrentDirectory := To_Unbounded_String(Value("HOME"));
         if not Ada.Directories.Exists(To_String(CurrentDirectory)) then
            CurrentDirectory := To_Unbounded_String("/");
         end if;
      end if;
      declare
         ApplicationsPaths: constant array
           (Positive range <>) of Unbounded_String :=
           (To_Unbounded_String("/usr/share/applications"),
            To_Unbounded_String("/usr/share/applnk"),
            To_Unbounded_String("/usr/local/share/applications"),
            To_Unbounded_String("/usr/local/share/applnk"),
            To_Unbounded_String(Value("HOME") & "/.local/share/applications"),
            To_Unbounded_String(Value("HOME") & "/.local/share/applnk"));
         SubDirectory: Dir_Type;
         SubLast: Natural;
         SubFileName: String(1 .. 1024);
         File: File_Type;
         FileLine: Unbounded_String;
         FilesList: constant Gtk_List_Store :=
           Gtk_List_Store(Get_Object(Builder, "applicationsstore"));
         FileIter: Gtk_Tree_Iter;
      begin
         for Path of ApplicationsPaths loop
            if not Ada.Directories.Exists(To_String(Path)) then
               goto End_Of_Loop;
            end if;
            Open(SubDirectory, To_String(Path));
            loop
               Read(SubDirectory, SubFileName, SubLast);
               exit when SubLast = 0;
               if Extension(SubFileName(1 .. SubLast)) = "desktop" then
                  Open
                    (File, In_File,
                     To_String(Path) & "/" &
                     Simple_Name(SubFileName(1 .. SubLast)));
                  while not End_Of_File(File) loop
                     FileLine := To_Unbounded_String(Get_Line(File));
                     if Length(FileLine) > 5
                       and then Slice(FileLine, 1, 5) = "Name=" then
                        Append(FilesList, FileIter);
                        Set
                          (FilesList, FileIter, 0,
                           Slice(FileLine, 6, Length(FileLine)));
                        Set(FilesList, FileIter, 1, SubFileName(1 .. SubLast));
                        exit;
                     end if;
                  end loop;
                  Close(File);
               end if;
            end loop;
            Close(SubDirectory);
            <<End_Of_Loop>>
         end loop;
      end;
      Set_Menu
        (Gtk_Menu_Tool_Button(Get_Object(Builder, "btnnew")),
         Gtk_Widget(Get_Object(Builder, "newmenu")));
      LoadDirectory(To_String(CurrentDirectory), "fileslist");
      Set_Menu
        (Gtk_Menu_Tool_Button(Get_Object(Builder, "btnbookmarks")),
         Gtk_Widget(Get_Object(Builder, "bookmarksmenu")));
      Show_All(Gtk_Widget(Get_Object(Builder, "mainwindow")));
      HideMessage(Builder);
      Hide(Gtk_Widget(Get_Object(Builder, "searchfile")));
      Hide(Gtk_Widget(Get_Object(Builder, "entry")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolapply")));
      Hide(Gtk_Widget(Get_Object(Builder, "btntoolcancel")));
      Set_Cursor
        (Gtk_Tree_View(Get_Object(Builder, "treefiles")),
         Gtk_Tree_Path_New_From_String("0"), null, False);
      Set_Position
        (Gtk_Paned(Get_Object(Builder, "filespaned")),
         Gint
           (Float
              (Get_Allocated_Width
                 (Gtk_Widget(Get_Object(Builder, "mainwindow")))) *
            0.3));
      Grab_Focus(Gtk_Widget(Get_Object(Builder, "treefiles")));
   end CreateMainWindow;

end MainWindow;
