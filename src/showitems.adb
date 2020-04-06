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

with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Characters.Latin_1; use Ada.Characters.Latin_1;
with Ada.Directories; use Ada.Directories;
with Ada.Environment_Variables; use Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO; use Ada.Text_IO;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with GNAT.String_Split; use GNAT.String_Split;
with CArgv;
with Tcl; use Tcl;
with Tcl.Ada;
with Tcl.Tk.Ada; use Tcl.Tk.Ada;
with Tcl.Tk.Ada.Grid;
with Tcl.Tk.Ada.Image; use Tcl.Tk.Ada.Image;
with Tcl.Tk.Ada.Image.Photo; use Tcl.Tk.Ada.Image.Photo;
with Tcl.Tk.Ada.Pack;
with Tcl.Tk.Ada.Widgets; use Tcl.Tk.Ada.Widgets;
with Tcl.Tk.Ada.Widgets.Canvas; use Tcl.Tk.Ada.Widgets.Canvas;
with Tcl.Tk.Ada.Widgets.Text; use Tcl.Tk.Ada.Widgets.Text;
with Tcl.Tk.Ada.Widgets.TtkButton; use Tcl.Tk.Ada.Widgets.TtkButton;
with Tcl.Tk.Ada.Widgets.TtkButton.TtkRadioButton;
use Tcl.Tk.Ada.Widgets.TtkButton.TtkRadioButton;
with Tcl.Tk.Ada.Widgets.TtkFrame; use Tcl.Tk.Ada.Widgets.TtkFrame;
with Tcl.Tk.Ada.Widgets.TtkLabel; use Tcl.Tk.Ada.Widgets.TtkLabel;
with Tcl.Tk.Ada.Widgets.TtkPanedWindow; use Tcl.Tk.Ada.Widgets.TtkPanedWindow;
with Tcl.Tk.Ada.Widgets.TtkScrollbar; use Tcl.Tk.Ada.Widgets.TtkScrollbar;
with Tcl.Tk.Ada.Widgets.TtkTreeView; use Tcl.Tk.Ada.Widgets.TtkTreeView;
with Tcl.Tk.Ada.Winfo; use Tcl.Tk.Ada.Winfo;
with LoadData; use LoadData;
with MainWindow; use MainWindow;
with Messages; use Messages;
with Preferences; use Preferences;
with Utils; use Utils;
--with Ada.Containers; use Ada.Containers;
--with Ada.Strings; use Ada.Strings;
--with GNAT.Directory_Operations; use GNAT.Directory_Operations;
--with GNAT.Expect; use GNAT.Expect;
--with GNAT.String_Split; use GNAT.String_Split;
--with Bookmarks; use Bookmarks;
--with CopyItems; use CopyItems;
--with CreateItems; use CreateItems;
--with LoadData; use LoadData;
--with MainWindow; use MainWindow;
--with MoveItems; use MoveItems;
--with Messages; use Messages;
--with ProgramsMenu; use ProgramsMenu;
--with SearchItems; use SearchItems;
--with Toolbars; use Toolbars;

package body ShowItems is

   PreviewFrame: Ttk_Frame;
   PreviewXScroll: Ttk_Scrollbar;
   PreviewYScroll: Ttk_Scrollbar;
   PreviewTree: Ttk_Tree_View;
   PreviewText: Tk_Text;
   PreviewCanvas: Tk_Canvas;
   InfoFrame: Ttk_Frame;

   package CreateCommands is new Tcl.Ada.Generic_Command(Integer);

   procedure ScaleImage is
      Image: constant Tk_Photo :=
        Create("previewimage", "-file " & To_String(CurrentSelected));
      TempImage: Tk_Photo := Create("tempimage");
      FrameWidth, FrameHeight, ImageWidth, ImageHeight, StartX,
      StartY: Natural;
      ScaleMode: Unbounded_String := To_Unbounded_String("-subsample");
      Scale: Natural;
   begin
      Delete(PreviewCanvas, "all");
      ImageWidth := Natural'Value(Width(Image));
      ImageHeight := Natural'Value(Height(Image));
      Copy(Image, TempImage);
      Blank(Image);
      FrameHeight := Natural'Value(Winfo_Get(PreviewFrame, "height"));
      FrameWidth := Natural'Value(Winfo_Get(PreviewFrame, "width"));
      if ImageWidth > FrameWidth or ImageHeight > FrameHeight then
         if ImageWidth / FrameWidth > ImageHeight / FrameHeight then
            Scale := ImageWidth / FrameWidth;
         else
            Scale := ImageHeight / FrameHeight;
         end if;
         Scale := Scale + 1;
      elsif FrameWidth > ImageWidth or FrameHeight > ImageHeight then
         ScaleMode := To_Unbounded_String("-zoom");
         if FrameWidth / ImageWidth > FrameHeight / ImageHeight then
            Scale := FrameWidth / ImageWidth;
         else
            Scale := FrameHeight / ImageHeight;
         end if;
      end if;
      Copy
        (TempImage, Image,
         "-shrink " & To_String(ScaleMode) & Natural'Image(Scale));
      Delete(TempImage);
      ImageWidth := Natural'Value(Width(Image));
      ImageHeight := Natural'Value(Height(Image));
      StartX := ImageWidth / 2;
      StartY := ImageHeight / 2;
      Canvas_Create
        (PreviewCanvas, "image",
         Natural'Image(StartX) & Natural'Image(StartY) & " -image " &
         Widget_Image(Image));
      configure
        (PreviewCanvas,
         "-width " & Width(Image) & " -height " & Height(Image) &
         " -scrollregion [list " & BBox(PreviewCanvas, "all") & "]");
   end ScaleImage;

   procedure ShowPreview is
   begin
      if Is_Directory(To_String(CurrentSelected)) then
         if not Is_Read_Accessible_File(To_String(CurrentSelected)) then
            ShowMessage
              ("You don't have permissions to preview this directory.");
         end if;
         LoadDirectory(To_String(CurrentSelected), True);
         Tcl.Tk.Ada.Pack.Pack_Forget(PreviewText);
         Tcl.Tk.Ada.Pack.Pack_Forget(PreviewCanvas);
         Tcl.Tk.Ada.Pack.Pack_Forget(InfoFrame);
         configure
           (PreviewYScroll,
            "-command [list " & Widget_Image(PreviewFrame) &
            ".directorytree yview]");
         configure
           (PreviewXScroll,
            "-command [list " & Widget_Image(PreviewFrame) &
            ".directorytree xview]");
         Tcl.Tk.Ada.Pack.Pack(PreviewXScroll, "-side bottom -fill x");
         Tcl.Tk.Ada.Pack.Pack(PreviewYScroll, "-side right -fill y");
         Tcl.Tk.Ada.Pack.Pack
           (PreviewTree, "-side top -fill both -expand true");
         UpdateDirectoryList(True, "preview");
      else
         declare
            MimeType: constant String :=
              GetMimeType(To_String(CurrentSelected));
         begin
            if MimeType(1 .. 4) = "text" then
               declare
                  ExecutableName: constant String :=
                    FindExecutable("highlight", False);
                  Success, FirstLine: Boolean;
                  File: File_Type;
                  FileLine, TagText, TagName: Unbounded_String;
                  StartIndex, EndIndex, StartColor: Natural;
                  procedure LoadFile is
                  begin
                     Open(File, In_File, To_String(CurrentSelected));
                     while not End_Of_File(File) loop
                        FileLine := To_Unbounded_String(Get_Line(File));
                        StartIndex := 1;
                        loop
                           StartIndex := Index(FileLine, "{", StartIndex);
                           exit when StartIndex = 0;
                           Replace_Slice
                             (FileLine, StartIndex, StartIndex, "\{");
                           StartIndex := StartIndex + 2;
                        end loop;
                        StartIndex := 1;
                        loop
                           StartIndex := Index(FileLine, "}", StartIndex);
                           exit when StartIndex = 0;
                           Replace_Slice
                             (FileLine, StartIndex, StartIndex, "\}");
                           StartIndex := StartIndex + 2;
                        end loop;
                        Insert
                          (PreviewText, "end",
                           "[subst -nocommands -novariables {" &
                           To_String(FileLine) & LF & "}]");
                     end loop;
                     Close(File);
                  end LoadFile;
               begin
                  Tcl.Tk.Ada.Pack.Pack_Forget(PreviewTree);
                  Tcl.Tk.Ada.Pack.Pack_Forget(PreviewCanvas);
                  Tcl.Tk.Ada.Pack.Pack_Forget(PreviewXScroll);
                  Tcl.Tk.Ada.Pack.Pack_Forget(InfoFrame);
                  configure
                    (PreviewYScroll,
                     "-command [list " & Widget_Image(PreviewText) &
                     " yview]");
                  Tcl.Tk.Ada.Pack.Pack(PreviewYScroll, "-side right -fill y");
                  Tcl.Tk.Ada.Pack.Pack
                    (PreviewText, "-side top -fill both -expand true");
                  configure(PreviewText, "-state normal");
                  Delete(PreviewText, "1.0", "end");
                  if not Settings.ColorText or ExecutableName = "" then
                     LoadFile;
                     goto Set_UI;
                  end if;
                  Spawn
                    (ExecutableName,
                     Argument_String_To_List
                       ("--out-format=pango --force --output=" &
                        Value("HOME") &
                        "/.cache/hunter/highlight.tmp --base16 --style=" &
                        To_String(Settings.ColorTheme) & " " &
                        To_String(CurrentSelected)).all,
                     Success);
                  if not Success then
                     LoadFile;
                     goto Set_UI;
                  end if;
                  Open
                    (File, In_File,
                     Value("HOME") & "/.cache/hunter/highlight.tmp");
                  FirstLine := True;
                  while not End_Of_File(File) loop
                     FileLine := To_Unbounded_String(Get_Line(File));
                     if FirstLine then
                        FileLine :=
                          Unbounded_Slice
                            (FileLine, Index(FileLine, ">") + 1,
                             Length(FileLine));
                        FirstLine := False;
                     end if;
                     exit when End_Of_File(File);
                     loop
                        StartIndex := Index(FileLine, "&gt;");
                        exit when StartIndex = 0;
                        Replace_Slice
                          (FileLine, StartIndex, StartIndex + 3, ">");
                     end loop;
                     loop
                        StartIndex := Index(FileLine, "&lt;");
                        exit when StartIndex = 0;
                        Replace_Slice
                          (FileLine, StartIndex, StartIndex + 3, "<");
                     end loop;
                     loop
                        StartIndex := Index(FileLine, "&amp;");
                        exit when StartIndex = 0;
                        Replace_Slice
                          (FileLine, StartIndex, StartIndex + 4, "&");
                     end loop;
                     StartIndex := 1;
                     loop
                        StartIndex := Index(FileLine, "{", StartIndex);
                        exit when StartIndex = 0;
                        Replace_Slice(FileLine, StartIndex, StartIndex, "\{");
                        StartIndex := StartIndex + 2;
                     end loop;
                     StartIndex := 1;
                     loop
                        StartIndex := Index(FileLine, "}", StartIndex);
                        exit when StartIndex = 0;
                        Replace_Slice(FileLine, StartIndex, StartIndex, "\}");
                        StartIndex := StartIndex + 2;
                     end loop;
                     StartIndex := 1;
                     loop
                        StartIndex := Index(FileLine, "<span", StartIndex);
                        exit when StartIndex = 0;
                        if StartIndex > 1 then
                           Insert
                             (PreviewText, "end",
                              "[subst -nocommands -novariables {" &
                              Slice(FileLine, 1, StartIndex - 1) & "}]");
                        end if;
                        EndIndex := Index(FileLine, ">", StartIndex);
                        TagText :=
                          Unbounded_Slice(FileLine, StartIndex, EndIndex);
                        StartColor := Index(TagText, "foreground=");
                        if Index(TagText, "foreground=") > 0 then
                           TagName :=
                             Unbounded_Slice
                               (TagText, StartColor + 12, StartColor + 18);
                           Tag_Configure
                             (PreviewText, To_String(TagName),
                              "-foreground " & To_String(TagName));
                        elsif Index(TagText, "style=""italic""") > 0 then
                           TagName := To_Unbounded_String("italictag");
                        elsif Index(TagText, "weight=""bold""") > 0 then
                           TagName := To_Unbounded_String("boldtag");
                        end if;
                        StartIndex := StartIndex + Length(TagText);
                        EndIndex := Index(FileLine, "</span>", StartIndex) - 1;
                        if EndIndex > 0 then
                           Insert
                             (PreviewText, "end",
                              "[subst -nocommands -novariables {" &
                              Slice(FileLine, StartIndex, EndIndex) &
                              "}] [list " & To_String(TagName) & "]");
                        else
                           Insert
                             (PreviewText, "end",
                              "[subst -nocommands -novariables {" &
                              Slice(FileLine, StartIndex, Length(FileLine)) &
                              "}]");
                        end if;
                        StartIndex := 1;
                        FileLine :=
                          Unbounded_Slice
                            (FileLine, EndIndex + 8, Length(FileLine));
                     end loop;
                     Insert
                       (PreviewText, "end",
                        "[subst -nocommands -novariables {" &
                        To_String(FileLine) & LF & "}]");
                  end loop;
                  Close(File);
                  Delete_File(Value("HOME") & "/.cache/hunter/highlight.tmp");
                  <<Set_UI>>
                  configure(PreviewText, "-state disabled");
               end;
            elsif MimeType(1 .. 5) = "image" then
               declare
                  Image: constant Tk_Photo :=
                    Create
                      ("previewimage", "-file " & To_String(CurrentSelected));
                  StartX, StartY, ImageWidth, ImageHeight: Natural;
               begin
                  Tcl.Tk.Ada.Pack.Pack_Forget(PreviewText);
                  Tcl.Tk.Ada.Pack.Pack_Forget(PreviewTree);
                  Tcl.Tk.Ada.Pack.Pack_Forget(InfoFrame);
                  if Settings.ScaleImages then
                     Tcl.Tk.Ada.Pack.Pack_Forget(PreviewYScroll);
                     Tcl.Tk.Ada.Pack.Pack_Forget(PreviewXScroll);
                     ScaleImage;
                  else
                     Delete(PreviewCanvas, "all");
                     ImageWidth := Natural'Value(Width(Image));
                     ImageHeight := Natural'Value(Height(Image));
                     StartX := ImageWidth / 2;
                     StartY := ImageHeight / 2;
                     Canvas_Create
                       (PreviewCanvas, "image",
                        Natural'Image(StartX) & Natural'Image(StartY) &
                        " -image " & Widget_Image(Image));
                     configure
                       (PreviewCanvas,
                        "-width " & Width(Image) & " -height " &
                        Height(Image) & " -scrollregion [list " &
                        BBox(PreviewCanvas, "all") & "]");
                     configure
                       (PreviewYScroll,
                        "-command [list " & Widget_Image(PreviewCanvas) &
                        " yview]");
                     configure
                       (PreviewXScroll,
                        "-command [list " & Widget_Image(PreviewCanvas) &
                        " xview]");
                     Tcl.Tk.Ada.Pack.Pack
                       (PreviewXScroll, "-side bottom -fill x");
                     Tcl.Tk.Ada.Pack.Pack
                       (PreviewYScroll, "-side right -fill y");
                  end if;
                  Tcl.Tk.Ada.Pack.Pack(PreviewCanvas, "-side top");
               end;
            else
               declare
                  ActionButton: Ttk_RadioButton;
               begin
                  ActionButton.Name :=
                    New_String(".mainframe.toolbars.itemtoolbar.infobutton");
                  ActionButton.Interp := Get_Context;
                  if Invoke(ActionButton) /= "" then
                     raise Program_Error
                       with "Can't show file or directory info";
                  end if;
               end;
            end if;
         end;
      end if;
   end ShowPreview;

   procedure ShowInfo is
      Label: Ttk_Label;
      SelectedItem: constant String := To_String(CurrentSelected);
   begin
      Tcl.Tk.Ada.Pack.Pack_Forget(PreviewText);
      Tcl.Tk.Ada.Pack.Pack_Forget(PreviewTree);
      Tcl.Tk.Ada.Pack.Pack_Forget(PreviewCanvas);
      Tcl.Tk.Ada.Pack.Pack_Forget(PreviewYScroll);
      Tcl.Tk.Ada.Pack.Pack_Forget(PreviewXScroll);
      Label.Interp := Get_Context;
      Label.Name := New_String(Widget_Image(InfoFrame) & ".fullpathtext");
      if not Is_Symbolic_Link(SelectedItem) then
         configure(Label, "-text {Full path:}");
      else
         configure(Label, "-text {Links to:}");
      end if;
      Label.Name := New_String(Widget_Image(InfoFrame) & ".fullpath");
      configure(Label, "-text {" & Full_Name(SelectedItem) & "}");
      Label.Name := New_String(Widget_Image(InfoFrame) & ".sizetext");
      if Is_Directory(SelectedItem) then
         configure(Label, "-text {Elements:}");
      else
         configure(Label, "-text {Size:}");
      end if;
      Label.Name := New_String(Widget_Image(InfoFrame) & ".size");
      if Is_Directory(SelectedItem) then
         configure
           (Label,
            "-text {" & Natural'Image(Natural(SecondItemsList.Length)) & "}");
      elsif Is_Regular_File(SelectedItem) then
         configure(Label, "-text {" & CountFileSize(Size(SelectedItem)) & "}");
      else
         configure(Label, "-text {Unknown}");
      end if;
      Label.Name := New_String(Widget_Image(InfoFrame) & ".lastmodified");
      configure
        (Label,
         "-text {" &
         Ada.Calendar.Formatting.Image
           (Modification_Time(SelectedItem), False,
            Ada.Calendar.Time_Zones.UTC_Time_Offset) &
         "}");
      Tcl.Tk.Ada.Pack.Pack(InfoFrame);
   end ShowInfo;

   function Show_Preview_Or_Info_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;

   function Show_Preview_Or_Info_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Argc, Argv);
   begin
      if Tcl.Ada.Tcl_GetVar(Interp, "previewtype") = "preview" then
         ShowPreview;
      else
         ShowInfo;
      end if;
      return TCL_OK;
   end Show_Preview_Or_Info_Command;

   function Show_Selected_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int with
      Convention => C;

   function Show_Selected_Command
     (ClientData: in Integer; Interp: in Tcl.Tcl_Interp;
      Argc: in Interfaces.C.int; Argv: in CArgv.Chars_Ptr_Ptr)
      return Interfaces.C.int is
      pragma Unreferenced(ClientData, Interp, Argc, Argv);
      DirectoryTree: Ttk_Tree_View;
      Tokens: Slice_Set;
      Items: Unbounded_String;
      ActionButton: Ttk_RadioButton;
   begin
      DirectoryTree.Interp := Get_Context;
      DirectoryTree.Name :=
        New_String(".mainframe.paned.directoryframe.directorytree");
      SelectedItems.Clear;
      Items := To_Unbounded_String(Selection(DirectoryTree));
      if Items = Null_Unbounded_String then
         return TCL_OK;
      end if;
      Create(Tokens, To_String(Items), " ");
      for I in 1 .. Slice_Count(Tokens) loop
         SelectedItems.Append
           (CurrentDirectory & "/" &
            ItemsList(Positive'Value(Slice(Tokens, I))).Name);
      end loop;
      if not Settings.ShowPreview or SelectedItems(1) = CurrentSelected then
         return TCL_OK;
      end if;
      CurrentSelected := SelectedItems(1);
      ActionButton.Interp := Get_Context;
      if Is_Directory(To_String(CurrentSelected)) or
        Is_Regular_File(To_String(CurrentSelected)) then
         ActionButton.Name :=
           New_String(".mainframe.toolbars.itemtoolbar.previewbutton");
      else
         ActionButton.Name :=
           New_String(".mainframe.toolbars.itemtoolbar.infobutton");
      end if;
      if Invoke(ActionButton) /= "" then
         raise Program_Error with "Can't show file or directory preview/info";
      end if;
      return TCL_OK;
   end Show_Selected_Command;

   procedure CreateShowItemsUI is
      Paned: Ttk_PanedWindow;
      Label: Ttk_Label;
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
      PreviewFrame := Create(".mainframe.paned.previewframe");
      PreviewXScroll :=
        Create
          (Widget_Image(PreviewFrame) & ".scrollx",
           "-orient horizontal -command [list " & Widget_Image(PreviewFrame) &
           ".directorytree xview]");
      PreviewYScroll :=
        Create
          (Widget_Image(PreviewFrame) & ".scrolly",
           "-orient vertical -command [list " & Widget_Image(PreviewFrame) &
           ".directorytree yview]");
      PreviewTree :=
        Create
          (Widget_Image(PreviewFrame) & ".directorytree",
           "-columns [list name] -xscrollcommand {" &
           Widget_Image(PreviewXScroll) & " set} -yscrollcommand {" &
           Widget_Image(PreviewYScroll) & " set} -selectmode none ");
      Heading
        (PreviewTree, "name",
         "-text {Name} -image {arrow-down} -command {Sort previewname}");
      Column(PreviewTree, "#0", "-stretch false -width 50");
      PreviewText :=
        Create
          (Widget_Image(PreviewFrame) & ".previewtext",
           "-wrap char -yscrollcommand """ & Widget_Image(PreviewYScroll) &
           " set""");
      Tag_Configure(PreviewText, "boldtag", "-font bold");
      Tag_Configure(PreviewText, "italictag", "-font italic");
      PreviewCanvas :=
        Create
          (Widget_Image(PreviewFrame) & ".previewcanvas",
           "-xscrollcommand """ & Widget_Image(PreviewXScroll) &
           " set"" -yscrollcommand """ & Widget_Image(PreviewYScroll) &
           " set""");
      InfoFrame := Create(Widget_Image(PreviewFrame) & ".infoframe");
      Label := Create(Widget_Image(InfoFrame) & ".fullpathtext");
      Tcl.Tk.Ada.Grid.Grid(Label);
      Label := Create(Widget_Image(InfoFrame) & ".fullpath");
      Tcl.Tk.Ada.Grid.Grid(Label, "-column 1 -row 0");
      Label := Create(Widget_Image(InfoFrame) & ".sizetext");
      Tcl.Tk.Ada.Grid.Grid(Label, "-column 0 -row 1");
      Label := Create(Widget_Image(InfoFrame) & ".size");
      Tcl.Tk.Ada.Grid.Grid(Label, "-column 1 -row 1");
      Label :=
        Create
          (Widget_Image(InfoFrame) & ".lastmodifiedtext",
           "-text {Last modified:}");
      Tcl.Tk.Ada.Grid.Grid(Label, "-column 0 -row 2");
      Label := Create(Widget_Image(InfoFrame) & ".lastmodified");
      Tcl.Tk.Ada.Grid.Grid(Label, "-column 1 -row 2");
      AddCommand("ShowSelected", Show_Selected_Command'Access);
      AddCommand("ShowPreviewOrInfo", Show_Preview_Or_Info_Command'Access);
      Paned.Interp := PreviewFrame.Interp;
      Paned.Name := New_String(".mainframe.paned");
      Add(Paned, PreviewFrame, "-weight 20");
   end CreateShowItemsUI;

--   -- ****if* ShowItems/ShowItemInfo
--   -- FUNCTION
--   -- Show detailed information (name, size, modification date, etc) about
--   -- selected file or directory.
--   -- PARAMETERS
--   -- Self - Gtk_Tool_Button clicked. Unused. Can be null
--   -- SOURCE
--   procedure ShowItemInfo(Self: access Gtk_Tool_Button_Record'Class) is
--      pragma Unreferenced(Self);
--      -- ****
--      Amount: Natural := 0;
--      Directory: Dir_Type;
--      Last: Natural;
--      FileName: String(1 .. 1024);
--      SelectedPath: Unbounded_String;
--      InfoGrid: constant Gtk_Grid :=
--        Gtk_Grid(Get_Child_By_Name(InfoStack, "info"));
--      Widgets: constant array(1 .. 7) of Gtk_Widget :=
--        (Get_Child_At(InfoGrid, 0, 3), Get_Child_At(InfoGrid, 1, 3),
--         Get_Child_At(InfoGrid, 0, 4), Get_Child_At(InfoGrid, 1, 4),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 3),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 3),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 3));
--   begin
--      if Setting or CurrentSelected = Null_Unbounded_String then
--         return;
--      end if;
--      Setting := True;
--      SelectedPath :=
--        To_Unbounded_String(Full_Name(To_String(CurrentSelected)));
--      Set_Label
--        (Gtk_Label(Get_Child_At(InfoGrid, 1, 0)), To_String(SelectedPath));
--      Set_Label(Gtk_Label(Get_Child_At(InfoGrid, 0, 1)), Gettext("Size:"));
--      if Is_Symbolic_Link(To_String(CurrentSelected)) then
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 0, 0)), Gettext("Links to:"));
--      else
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 0, 0)), Gettext("Full path:"));
--      end if;
--      for Widget of Widgets loop
--         Hide(Widget);
--      end loop;
--      if Is_Regular_File(To_String(SelectedPath)) then
--         for Widget of Widgets loop
--            Show_All(Widget);
--         end loop;
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 1, 1)),
--            CountFileSize(Size(To_String(SelectedPath))));
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 1, 2)),
--            Ada.Calendar.Formatting.Image
--              (Modification_Time(To_String(SelectedPath)), False,
--               Ada.Calendar.Time_Zones.UTC_Time_Offset));
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 1, 3)),
--            GetMimeType(To_String(SelectedPath)));
--         if not CanBeOpened(GetMimeType(To_String(SelectedPath))) then
--            Set_Label
--              (Gtk_Button(Get_Child_At(InfoGrid, 1, 4)), Gettext("none"));
--         else
--            declare
--               ProcessDesc: Process_Descriptor;
--               Result: Expect_Match;
--               ExecutableName: constant String := FindExecutable("xdg-mime");
--               DesktopFile: Unbounded_String;
--            begin
--               if ExecutableName = "" then
--                  return;
--               end if;
--               Non_Blocking_Spawn
--                 (ProcessDesc, ExecutableName,
--                  Argument_String_To_List
--                    ("query default " &
--                     GetMimeType(To_String(SelectedPath))).all);
--               Expect(ProcessDesc, Result, Regexp => ".+", Timeout => 1_000);
--               if Result = 1 then
--                  DesktopFile :=
--                    To_Unbounded_String(Expect_Out_Match(ProcessDesc));
--                  GetProgramName(DesktopFile);
--                  if Index(DesktopFile, ".desktop") = 0 then
--                     Set_Label
--                       (Gtk_Button(Get_Child_At(InfoGrid, 1, 4)),
--                        To_String(DesktopFile));
--                  else
--                     Set_Label
--                       (Gtk_Button(Get_Child_At(InfoGrid, 1, 4)),
--                        To_String(DesktopFile) & Gettext(" (not installed)"));
--                  end if;
--               end if;
--               Close(ProcessDesc);
--            end;
--         end if;
--      elsif Is_Directory(To_String(SelectedPath)) then
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 0, 1)), Gettext("Elements:"));
--         if Is_Read_Accessible_File(To_String(SelectedPath)) then
--            Open(Directory, To_String(SelectedPath));
--            loop
--               Read(Directory, FileName, Last);
--               exit when Last = 0;
--               Amount := Amount + 1;
--            end loop;
--            Close(Directory);
--            Set_Label
--              (Gtk_Label(Get_Child_At(InfoGrid, 1, 1)),
--               Natural'Image(Amount - 2));
--         else
--            Set_Label
--              (Gtk_Label(Get_Child_At(InfoGrid, 1, 1)), Gettext("Unknown"));
--         end if;
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 1, 2)),
--            Ada.Calendar.Formatting.Image
--              (Modification_Time(To_String(SelectedPath))));
--      else
--         if SelectedPath = "" then
--            Set_Label
--              (Gtk_Label(Get_Child_At(InfoGrid, 1, 0)), Gettext("Unknown"));
--         end if;
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 1, 1)), Gettext("Unknown"));
--         for I in 5 .. 7 loop
--            Show_All(Widgets(I));
--         end loop;
--         Set_Label
--           (Gtk_Label(Get_Child_At(InfoGrid, 1, 2)), Gettext("Unknown"));
--      end if;
--      declare
--         ProcessDesc: Process_Descriptor;
--         Result: Expect_Match;
--         FileStats: Unbounded_String;
--         Tokens: Slice_Set;
--         Buttons: constant array(3 .. 11) of Gtk_Widget :=
--           (Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 1),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 2),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 3),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 1),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 2),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 3),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 1),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 2),
--            Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 3));
--         CanChange: Boolean := False;
--         Button: Gtk_Toggle_Button;
--         Arguments: constant Argument_List :=
--           (new String'("-c""%A %U %G"),
--            new String'(To_String(CurrentSelected)));
--      begin
--         Non_Blocking_Spawn(ProcessDesc, "stat", Arguments);
--         Expect(ProcessDesc, Result, Regexp => ".+", Timeout => 1_000);
--         if Result = 1 then
--            FileStats := To_Unbounded_String(Expect_Out_Match(ProcessDesc));
--            Create(Tokens, To_String(FileStats), " ");
--            Set_Label
--              (Gtk_Label(Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 0)),
--               Slice(Tokens, 2));
--            Set_Label
--              (Gtk_Label(Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 0)),
--               Slice(Tokens, 3)
--                 (Slice(Tokens, 3)'First .. Slice(Tokens, 3)'Last));
--            if Value("USER") = Slice(Tokens, 2) then
--               CanChange := True;
--            end if;
--            for I in Buttons'Range loop
--               Button := Gtk_Toggle_Button(Buttons(I));
--               if Slice(Tokens, 1)(I) = '-' then
--                  Set_Active(Button, False);
--               else
--                  Set_Active(Button, True);
--               end if;
--               Set_Sensitive(Gtk_Widget(Button), CanChange);
--            end loop;
--         end if;
--         Close(ProcessDesc);
--      exception
--         when Process_Died =>
--            return;
--      end;
--      Set_Markup
--        (Gtk_Label
--           (Get_Label_Widget
--              (Gtk_Frame(Get_Child(Gtk_Box(Get_Child2(FilesPaned)), 1)))),
--         "<b>" & Gettext("Information") & "</b>");
--      Set_Visible_Child_Name(InfoStack, "info");
--      if not Get_Active
--          (Gtk_Radio_Tool_Button(Get_Nth_Item(ItemToolBar, 5))) then
--         Set_Active(Gtk_Radio_Tool_Button(Get_Nth_Item(ItemToolBar, 5)), True);
--      end if;
--      Setting := False;
--   end ShowItemInfo;
--
--   procedure ShowItem(Self: access Gtk_Tree_Selection_Record'Class) is
--   begin
--      SelectedItems.Clear;
--      Selected_Foreach(Self, GetSelectedItems'Access);
--      if Get_Active
--          (Gtk_Toggle_Tool_Button(Get_Nth_Item(ActionToolBar, 7))) then
--         MoveItemsList := SelectedItems;
--         return;
--      end if;
--      if Get_Active
--          (Gtk_Toggle_Tool_Button(Get_Nth_Item(ActionToolBar, 6))) then
--         CopyItemsList := SelectedItems;
--         return;
--      end if;
--      if SelectedItems.Length > 1 then
--         Hide(ItemToolBar);
--         Set_Markup
--           (Gtk_Label
--              (Get_Label_Widget
--                 (Gtk_Frame(Get_Child(Gtk_Box(Get_Child2(FilesPaned)), 1)))),
--            "<b>" & Gettext("Preview") & "</b>");
--         Set_Visible_Child_Name(InfoStack, "preview");
--         return;
--      elsif SelectedItems.Length = 0 then
--         PreviewItem(null);
--         return;
--      end if;
--      if CurrentSelected = SelectedItems(1) then
--         return;
--      end if;
--      CurrentSelected := SelectedItems(1);
--      if Setting or (not Settings.ShowPreview) then
--         SetBookmarkButton;
--         return;
--      end if;
--      if NewAction = CREATELINK then
--         LinkTarget := CurrentSelected;
--         return;
--      end if;
--      Show_All(ItemToolBar);
--      Set_Active(Gtk_Radio_Tool_Button(Get_Nth_Item(ItemToolBar, 4)), True);
--      PreviewItem(null);
--   end ShowItem;
--
--   -- ****if* ShowItems/SetPermission
--   -- FUNCTION
--   -- Set selected permissions to selected file or directory
--   -- PARAMETERS
--   -- Self - Gtk_Check_Button which was (un)checked. Unused. Can be null.
--   -- SOURCE
--   procedure SetPermission(Self: access Gtk_Toggle_Button_Record'Class) is
--      pragma Unreferenced(Self);
--      -- ****
--      InfoGrid: constant Gtk_Grid :=
--        Gtk_Grid(Get_Child_By_Name(InfoStack, "info"));
--      Buttons: constant array(2 .. 10) of Gtk_Widget :=
--        (Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 1),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 2),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 5)), 3),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 1),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 2),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 6)), 3),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 1),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 2),
--         Get_Child(Gtk_Box(Get_Child_At(InfoGrid, 1, 7)), 3));
--      UserPermission, GroupPermission, OthersPermission: Natural := 0;
--      Success: Boolean;
--      Arguments: Argument_List(1 .. 2);
--   begin
--      if Setting then
--         return;
--      end if;
--      for I in Buttons'Range loop
--         if Get_Active(Gtk_Toggle_Button(Buttons(I))) then
--            case I is
--               when 2 =>
--                  UserPermission := UserPermission + 4;
--               when 3 =>
--                  UserPermission := UserPermission + 2;
--               when 4 =>
--                  UserPermission := UserPermission + 1;
--               when 5 =>
--                  GroupPermission := GroupPermission + 4;
--               when 6 =>
--                  GroupPermission := GroupPermission + 2;
--               when 7 =>
--                  GroupPermission := GroupPermission + 1;
--               when 8 =>
--                  OthersPermission := OthersPermission + 4;
--               when 9 =>
--                  OthersPermission := OthersPermission + 2;
--               when 10 =>
--                  OthersPermission := OthersPermission + 1;
--            end case;
--         end if;
--      end loop;
--      Arguments :=
--        (new String'
--           (Trim(Natural'Image(UserPermission), Both) &
--            Trim(Natural'Image(GroupPermission), Both) &
--            Trim(Natural'Image(OthersPermission), Both)),
--         new String'(To_String(CurrentSelected)));
--      Spawn(Locate_Exec_On_Path("chmod").all, Arguments, Success);
--      if not Success then
--         ShowMessage
--           (Gettext("Could not change permissions for ") &
--            To_String(CurrentSelected));
--      end if;
--   end SetPermission;
--
--   -- ****if* ShowItems/SetDestination
--   -- FUNCTION
--   -- Enter subdirectory in preview for destination directory
--   -- PARAMETERS
--   -- Self   - Gtk_Tree_View which triggered this code
--   -- Path   - Gtk_Tree_Path to item which was activated
--   -- Column - Gtk_Tree_View_Column which was activated. Unused.
--   -- SOURCE
--   procedure SetDestination
--     (Self: access Gtk_Tree_View_Record'Class; Path: Gtk_Tree_Path;
--      Column: not null access Gtk_Tree_View_Column_Record'Class) is
--      pragma Unreferenced(Column);
--      -- ****
--   begin
--      CurrentSelected :=
--        CurrentDirectory &
--        To_Unbounded_String
--          ("/" &
--           Get_String(Get_Model(Self), Get_Iter(Get_Model(Self), Path), 0));
--      DestinationPath := CurrentSelected;
--      if Is_Directory(To_String(CurrentSelected)) then
--         if not Is_Read_Accessible_File(To_String(CurrentSelected)) then
--            ShowMessage(Gettext("You can't enter this directory."));
--            return;
--         end if;
--         if CurrentDirectory = To_Unbounded_String("/") then
--            CurrentDirectory := Null_Unbounded_String;
--         end if;
--         CurrentDirectory := CurrentSelected;
--         LoadDirectory(To_String(CurrentDirectory), "fileslist2");
--         Set_Cursor(Self, Gtk_Tree_Path_New_From_String("0"), null, False);
--         Grab_Focus(Gtk_Widget(Self));
--      end if;
--   end SetDestination;
--
--   procedure CreateShowItemsUI is
--      ProgramsButton: constant Gtk_Menu_Button := Gtk_Menu_Button_New;
--      InfoGrid: constant Gtk_Grid := Gtk_Grid_New;
--      Scroll: Gtk_Scrolled_Window := Gtk_Scrolled_Window_New;
--      procedure AddLabel(Text: String; Left, Top: Gint) is
--         Label: constant Gtk_Label := Gtk_Label_New(Text);
--      begin
--         Set_Halign(Label, Align_Start);
--         Set_Valign(Label, Align_Start);
--         Attach(InfoGrid, Label, Left, Top);
--      end AddLabel;
--      procedure AddBox(Top: Gint) is
--         Box: constant Gtk_Vbox := Gtk_Vbox_New;
--         Label: constant Gtk_Label := Gtk_Label_New("");
--         procedure AddButton(Text: String) is
--            CheckButton: constant Gtk_Check_Button :=
--              Gtk_Check_Button_New_With_Label(Text);
--         begin
--            On_Toggled(Gtk_Toggle_Button(CheckButton), SetPermission'Access);
--            Pack_Start(Box, CheckButton, False);
--         end AddButton;
--      begin
--         Pack_Start(Box, Label, False);
--         AddButton(Gettext("Can read"));
--         AddButton(Gettext("Can write"));
--         AddButton(Gettext("Can execute"));
--         Attach(InfoGrid, Box, 1, Top);
--      end AddBox;
--   begin
--      On_Clicked
--        (Gtk_Tool_Button(Get_Nth_Item(ItemToolBar, 4)), PreviewItem'Access);
--      On_Clicked
--        (Gtk_Tool_Button(Get_Nth_Item(ItemToolBar, 5)), ShowItemInfo'Access);
--      InfoStack := Gtk_Stack_New;
--      Add_Named(InfoStack, Scroll, "preview");
--      Set_Halign(InfoGrid, Align_Center);
--      AddLabel(Gettext("Full path:"), 0, 0);
--      AddLabel("", 1, 0);
--      AddLabel(Gettext("Size:"), 0, 1);
--      AddLabel("", 1, 1);
--      AddLabel(Gettext("Last Modified:"), 0, 2);
--      AddLabel("", 1, 2);
--      AddLabel(Gettext("File type:"), 0, 3);
--      AddLabel("", 1, 3);
--      AddLabel(Gettext("Associated program:"), 0, 4);
--      Set_Popover
--        (ProgramsButton, CreateProgramsMenu(Gtk_Widget(ProgramsButton)));
--      Attach(InfoGrid, ProgramsButton, 1, 4);
--      AddLabel(Gettext("Owner:"), 0, 5);
--      AddBox(5);
--      AddLabel(Gettext("Group:"), 0, 6);
--      AddBox(6);
--      AddLabel(Gettext("Others:"), 0, 7);
--      AddBox(7);
--      Show_All(InfoGrid);
--      Add_Named(InfoStack, InfoGrid, "info");
--      declare
--         DirectoryView: constant Gtk_Tree_View :=
--           Gtk_Tree_View_New_With_Model
--             (+(Gtk_Tree_Model_Sort_Sort_New_With_Model
--                 (+(Gtk_Tree_Model_Filter_Filter_New
--                     (+(Gtk_List_Store_Newv
--                         ((GType_String, GType_Uint, GType_String,
--                           GType_String, GType_Uint))))))));
--         Area: Gtk_Cell_Area_Box;
--         Renderer: Gtk_Cell_Renderer_Text := Gtk_Cell_Renderer_Text_New;
--         Renderer2: constant Gtk_Cell_Renderer_Pixbuf :=
--           Gtk_Cell_Renderer_Pixbuf_New;
--         Column: Gtk_Tree_View_Column;
--         Value: GValue;
--         PreviewFrame: constant Gtk_Frame := Gtk_Frame_New;
--         PreviewLabel: constant Gtk_Label := Gtk_Label_New;
--         PreviewBox: constant Gtk_Vbox := Gtk_Vbox_New;
--      begin
--         Set_Enable_Search(DirectoryView, False);
--         Set_Headers_Clickable(DirectoryView, True);
--         Area := Gtk_Cell_Area_Box_New;
--         Pack_Start(Area, Renderer2, False);
--         Add_Attribute(Area, Renderer2, "icon-name", 2);
--         Pack_Start(Area, Renderer, True);
--         Add_Attribute(Area, Renderer, "text", 0);
--         Init_Set_Int(Value, 80);
--         Set_Property(Renderer, "max-width-chars", Value);
--         Unset(Value);
--         Init_Set_Boolean(Value, True);
--         Set_Property(Renderer, "ellipsize-set", Value);
--         Unset(Value);
--         Init_Set_Int(Value, 1);
--         Set_Property(Renderer, "ellipsize", Value);
--         Unset(Value);
--         Column := Gtk_Tree_View_Column_New_With_Area(Area);
--         Set_Sort_Column_Id(Column, 0);
--         Set_Title(Column, Gettext("Name"));
--         Set_Resizable(Column, True);
--         Set_Expand(Column, True);
--         if Append_Column(DirectoryView, Column) /= 1 then
--            return;
--         end if;
--         Area := Gtk_Cell_Area_Box_New;
--         Renderer := Gtk_Cell_Renderer_Text_New;
--         Pack_Start(Area, Renderer, True);
--         Add_Attribute(Area, Renderer, "text", 3);
--         Column := Gtk_Tree_View_Column_New_With_Area(Area);
--         Set_Sort_Column_Id(Column, 4);
--         Set_Title(Column, Gettext("Size"));
--         Set_Resizable(Column, True);
--         if Append_Column(DirectoryView, Column) /= 2 then
--            return;
--         end if;
--         On_Row_Activated(DirectoryView, SetDestination'Access);
--         Scroll := Gtk_Scrolled_Window_New;
--         Add(Scroll, DirectoryView);
--         Add_Named(InfoStack, Scroll, "destination");
--         Set_Shadow_Type(PreviewFrame, Shadow_None);
--         Set_Label_Align(PreviewFrame, 0.5, 0.5);
--         Set_Markup(PreviewLabel, "<b>" & Gettext("Preview") & "</b>");
--         Set_Label_Widget(PreviewFrame, PreviewLabel);
--         Add(PreviewFrame, InfoStack);
--         Pack_Start(PreviewBox, Gtk_Flow_Box_New, False);
--         Pack_Start(PreviewBox, PreviewFrame);
--         Add2(FilesPaned, PreviewBox);
--      end;
--   end CreateShowItemsUI;

end ShowItems;
