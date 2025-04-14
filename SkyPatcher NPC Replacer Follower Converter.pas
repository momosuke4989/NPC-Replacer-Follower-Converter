unit userscript;

interface
implementation
uses xEditAPI, SysUtils, StrUtils, Windows;

const
  // Default value for each change. Specify by Form ID
  DEFAULT_WEAPON_ITEM = $0001397E;            // 0001397E Iron Dagger
  DEFAULT_AI_PACKAGE = $0001B217;             // 0001B217 DefaultSandboxEditorLocation512
  DEFAULT_COMBAT_STYLE = $0003BE1B;           // 0003BE1B csHumanMeleeLvl1
  DEFAULT_OUTFIT = $0009D5DF;                 // 0009D5DF FarmClothesOutfit04
  DEFAULT_FOLLOWER_VOICE_MALE = $00013AD2;    // 00013AD2 MaleEvenToned
  DEFAULT_FOLLOWER_VOICE_FEMALE = $00013ADD;  // 00013ADD FemaleEvenToned
  DEFAULT_ADD_PERK = $0005820C;               // 0005820C Light Foot
  
  // Option to exclude NPCs with the Use Traits flag
  DISABLE_USE_TRAITS_TEMPLATE_NPC = True;
  
  // Constants related to searching for cells to place NPCs
  SERCH_EXCLUDE_VANILLA_FILES = False;  // Whether to search for vanilla game files
  MAX_SERCH_FILES_COUNT = 30;           // Maximum number of plugin files loaded
  
  // Used to reference the source. Change prohibited
  POTENTIAL_MARRIAGE_FACTION = $00019809;
  POTENTIAL_FOLLOWER_FACTION = $0005C84D;
  CURRENT_FOLLOWER_FACTION = $0005C84E;
  LYDIA_PLAYER_RELATIONSHIP = $00103AED;
var
  potMarriageFac, potFollowerFac, curFollowerFac: IwbMainRecord;
  defaultWeaponItem, defaultAIPackage, defaultCombatStyle, defaultOutfit, defaultFollowerVoiceMale, defaultFollowerVoiceFemale, addPerk: IwbMainRecord;
  fileSearchOffset: Integer;
  enableSetVMADS, enableSetAIPackages, enableSetCombatStyle, enableSetName, enableSetOutfit, enableSetInventory, enableSetFlags, enableSetVoice: boolean;
  enableSetEssentialProtected, enableSetFactions, enableAddPerks, enableAddRelationship, enableAddHomeLocation: boolean;
  newNPCPlaced : boolean;
  defaultProtected, defaultEssential: string;

function ShowCheckboxForm(const options: TStringList; out selected: TStringList): Boolean;
var
  form: TForm;
  checklist: TCheckListBox;
  btnOK, btnCancel: TButton;
  i: Integer;
begin
  Result := False;

  form := TForm.Create(nil);
  try
    form.Caption := 'Select Options';
    form.Width := 350;
    form.Height := 300;
    form.Position := poScreenCenter;

    checklist := TCheckListBox.Create(form);
    checklist.Parent := form;
    checklist.Align := alTop;
    checklist.Height := 200;

    // Add a choice
    for i := 0 to options.Count - 1 do begin
      checklist.Items.Add(options[i]);
      checklist.Checked[i] := True;
    end;

    btnOK := TButton.Create(form);
    btnOK.Parent := form;
    btnOK.Caption := 'OK';
    btnOK.ModalResult := mrOk;
    btnOK.Width := 75;
    btnOK.Top := checklist.Top + checklist.Height + 10;
    btnOK.Left := (form.ClientWidth div 2) - btnOK.Width - 10;

    btnCancel := TButton.Create(form);
    btnCancel.Parent := form;
    btnCancel.Caption := 'Cancel';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Width := 75;
    btnCancel.Top := btnOK.Top;
    btnCancel.Left := (form.ClientWidth div 2) + 10;

    form.BorderStyle := bsDialog;
    form.Position := poScreenCenter;

    if form.ShowModal = mrOk then
    begin
      Result := True;
      for i := 0 to checklist.Items.Count - 1 do
        if checklist.Checked[i] then
          selected.Add('True')
        else
          selected.Add('False');
    end;
  finally
    form.Free;
  end;
end;

function FindNPCPlacedRecord(baseNPCRecord: IwbMainRecord;): IwbMainRecord;
var
  refRecord: IwbMainRecord;
  i: integer;
  findRecordFlag: boolean;
begin
  Result := nil;
  findRecordFlag := false;
  for i := 0 to Pred(ReferencedByCount(baseNPCRecord)) do begin
    // Scan for records that reference the replaced NPC record
    refRecord := ReferencedByIndex(baseNPCRecord, i);
    //AddMessage(IntToStr(i) + '. RefernceRecord Signature: ' + Signature(refRecord));
    if Signature(refRecord) = 'ACHR' then begin
      Result := refRecord;
      findRecordFlag := true;
      break;
    end;
  end;
  if findRecordFlag then
    AddMessage('Success to find ACHR record.')
  else
    AddMessage('Failed to find ACHR record.');
end;

function Initialize: integer;
var
    opts, selected: TStringList;
    i: Integer;
begin
  opts                := TStringList.Create;
  selected            := TStringList.Create;
  Result := 0;
  
  // Set record variables
  // TODO:Added a process to check whether the record settings are correct.
  potMarriageFac := RecordByFormID(FileByIndex(0), POTENTIAL_MARRIAGE_FACTION, True);
  potFollowerFac := RecordByFormID(FileByIndex(0), POTENTIAL_FOLLOWER_FACTION, True);
  curFollowerFac := RecordByFormID(FileByIndex(0), CURRENT_FOLLOWER_FACTION, True);
  
  defaultWeaponItem := RecordByFormID(FileByIndex(0), DEFAULT_WEAPON_ITEM, True);
  defaultAIPackage := RecordByFormID(FileByIndex(0), DEFAULT_AI_PACKAGE, True);
  defaultCombatStyle := RecordByFormID(FileByIndex(0), DEFAULT_COMBAT_STYLE, True);
  defaultOutfit := RecordByFormID(FileByIndex(0), DEFAULT_OUTFIT, True);
  defaultFollowerVoiceMale := RecordByFormID(FileByIndex(0), DEFAULT_FOLLOWER_VOICE_MALE, True);
  defaultFollowerVoiceFemale := RecordByFormID(FileByIndex(0), DEFAULT_FOLLOWER_VOICE_FEMALE, True);
  
  addPerk := RecordByFormID(FileByIndex(0), DEFAULT_ADD_PERK, True);
  
  // Option flag variables
  enableSetVMADS := false;
  enableSetAIPackages := false;
  enableSetCombatStyle := false;
  enableSetName := false;
  enableSetOutfit := false;
  enableSetInventory := false;
  enableSetFlags := false;
  enableSetVoice := false;
  enableSetEssentialProtected := false;
  enableSetFactions := false;
  
  enableAddPerks := false;
  enableAddRelationship := false;
  enableAddHomeLocation := false;
  
  // Protected/Essential flag. Only one of them can be turned on.
  defaultProtected := '0';
  defaultEssential := '0';
  
  // Setting each options
  try
    opts.Add('Set VMADS');
    opts.Add('Set AI Packages');
    opts.Add('Set Combat Style');
    opts.Add('Set Name');
    opts.Add('Set Outfit');
    opts.Add('Set Inventory');
    opts.Add('Set Flags');
    opts.Add('Set Voice');
    opts.Add('Set Immortality');
    opts.Add('Set Factions');
    opts.Add('Add Perks');
    opts.Add('Add Relationship');
    opts.Add('Add Home Location');

    if ShowCheckboxForm(opts, selected) then
    begin
      AddMessage('You selected:');
      for i := 0 to selected.Count - 1 do
        AddMessage(opts[i] + ' - ' + selected[i]);
    end
    else begin
      AddMessage('Selection was canceled.');
      Result := -1;
      Exit;
    end;
    

  
    // Store the checkbox input in a flag variables
    if selected[0] = 'True' then
      enableSetVMADS := true;
      
    if selected[1] = 'True' then
      enableSetAIPackages := true;
      
    if selected[2] = 'True' then
      enableSetCombatStyle := true;
      
    if selected[3] = 'True' then
      enableSetName := true;
      
    if selected[4] = 'True' then
      enableSetOutfit := true;
      
    if selected[5] = 'True' then
      enableSetInventory := true;
      
    if selected[6] = 'True' then
      enableSetFlags := true;
      
    if selected[7] = 'True' then
      enableSetVoice := true;
      
    if selected[8] = 'True' then
      enableSetEssentialProtected := true;
      
    if selected[9] = 'True' then
      enableSetFactions := true;
      
    if selected[10] = 'True' then
      enableAddPerks := true;
      
    if selected[11] = 'True' then
      enableAddRelationship := true;
      
    if selected[12] = 'True' then
      enableAddHomeLocation := true;
      
  finally
    opts.Free;
    selected.Free;
  end;

  if enableAddHomeLocation then begin
    // Check number of files loaded
    if FileCount > MAX_SERCH_FILES_COUNT then begin
      // Ask user if they want to continue as there are too many files loaded
      AddMessage('Too many loaded files!');
      if MessageDlg('Too many files were loaded. The script may take a long time to process. Continue?', mtConfirmation, [mbYes, mbNo], 0) = mrNo then begin
        Result := -1;
        Exit;
      end;
    end;
    
    // Set offset to exclude vanilla game files from search
    if SERCH_EXCLUDE_VANILLA_FILES then
      fileSearchOffset := 5
    else
      fileSearchOffset := 0;
  end;
  
  if enableSetEssentialProtected then begin
    if MessageDlg('Would you like to set it to Essential or Protected? (Yes: Essential, No: Protected)', mtConfirmation, [mbYes, mbNo], 0) = mrNo then
      defaultProtected := '1'
    else
      defaultEssential := '1';
  end
end;

function Process(e: IInterface): integer;
var
  vmad, factions, newFaction, aiPackages, newAiPackage, perks, newPerk, combatStyle, outfit, inventory, newItem, itemRecord, flags: IInterface;
  relRecordGroup, npcRecordGroup: IwbGroupRecord;
  existRelRec, baseNPCRecord, NPC_ACHRRecord, refCell, newCell, baseRel, rel: IwbMainRecord;
  baseFile : IwbFile;
  NPCEditorID, baseNPCEditorID, npcName, nameSuffix, relEditorID, itemType, voice: string;
  i, underscorePos, templateFlags: integer;
begin
  // Process only NPC records
  if Signature(e) <> 'NPC_' then Exit;

  AddMessage('Modifying NPC: ' + EditorID(e));
  
  // Depending on the option, NPCs with the UseTraits flag will skip processing.
  if DISABLE_USE_TRAITS_TEMPLATE_NPC then begin
    templateFlags := GetElementNativeValues(ElementBySignature(e, 'ACBS'), 'Template Flags');
    if (templateFlags and $01) <> 0 then begin
      AddMessage('This NPC has the Use Traits flag set. Skip processing.');
      Exit;
    end;
  end;

  NPCEditorID := GetElementEditValues(e, 'EDID');
  
  // Get the EditorID of the original NPC to be replaced from the EditorID
  underscorePos := LastDelimiter('_', NPCEditorID);
  baseNPCEditorID := Copy(NPCEditorID, underscorePos + 1, Length(NPCEditorID) - underscorePos);
  //AddMessage('Base NPC Editor ID: ' + baseNPCEditorID);
    
  // Delete quest script
  if enableSetVMADS then begin
    vmad := ElementBySignature(e, 'VMAD');
    if Assigned(vmad) then
      RemoveElement(e, 'VMAD');
  end;

  // Set AI package
  if enableSetAIPackages then begin
    aiPackages := ElementByPath(e, 'Packages');
    if Assigned(aiPackages) then
      RemoveElement(e, 'Packages');
    
    aiPackages := Add(e, 'Packages', True);
    RemoveElement(aiPackages, ElementByIndex(aiPackages, 0));
    
    newAiPackage := ElementAssign(aiPackages, HighInteger, nil, False);
    SetEditValue(newAiPackage, IntToHex(GetLoadOrderFormID(defaultAIPackage), 8));
  end;

  // Set Combat Style
  if enableSetCombatStyle then begin
    if GetElementEditValues(e, 'ZNAM') = '' then
      begin
        // Get or create Combat Style element
        if not Assigned(ElementByPath(e, 'ZNAM')) then
          Add(e, 'ZNAM', True);
        SetElementEditValues(e, 'ZNAM', IntToHex(GetLoadOrderFormID(defaultCombatStyle), 8));
      end
  end;
  
  // Set name
  // TODO:Output the formID and EditorID of NPCs whose names were blank to a .txt file.
  if enableSetName then begin
    npcName := GetElementEditValues(e, 'FULL');
    // If name is blank, assign it the Editor ID to replace
    if npcName = '' then
      npcName := baseNPCEditorID;
    nameSuffix := ' [' + Copy(NPCEditorID, 0, underscorePos - 1) + ']';
    if Pos(nameSuffix, npcName) = 0 then begin
      npcName := npcName + nameSuffix;
      SetElementEditValues(e, 'FULL', npcName);
    end;
    // Add prefix after default name
    //npcName := npcName + nameSuffix;
    //SetElementEditValues(e, 'FULL', npcName);
  end;

  // Set voice type
  if enableSetVoice then begin
    voice := GetElementEditValues(e, 'VTCK');
    if voice = '' then begin
      AddMessage(EditorID(e) +' does not set Voice Type.');
      Add(e, 'VTCK', True);
      flags := ElementByPath(e, 'ACBS - Configuration');
      
      if Assigned(flags) then begin
        if (GetElementNativeValues(flags, 'Flags\Female') and $01) <> 0 then
          SetElementEditValues(e, 'VTCK', IntToHex(GetLoadOrderFormID(defaultFollowerVoiceFemale), 8))
        else
          SetElementEditValues(e, 'VTCK', IntToHex(GetLoadOrderFormID(defaultFollowerVoiceMale), 8));
      end;
      AddMessage(EditorID(e) +' set Voice Type is ' + GetElementEditValues(e, 'VTCK'));
    end;
  end;

  // Set Outfit
  if enableSetOutfit then begin
    outfit := ElementBySignature(e, 'DOFT');
    if not Assigned(outfit) then
      Add(e, 'DOFT', True);
    SetElementEditValues(e, 'DOFT', IntToHex(GetLoadOrderFormID(defaultOutfit), 8));
  end;
  
  // Set Items
  if enableSetInventory then begin
    // Get inventory list
    inventory := ElementByPath(e, 'Items');
    // Clear inventory
    if Assigned(inventory) then
      RemoveElement(e, 'Items');
    // Re-add inventory
    inventory := Add(e, 'Items', True);
    RemoveElement(inventory, ElementByIndex(inventory, 0));
    // Set weapon item
    newItem := ElementAssign(inventory, HighInteger, nil, False);
    SetElementEditValues(newItem, 'CNTO - Item\Item', Name(defaultWeaponItem));
    SetElementEditValues(newItem, 'CNTO - Item\Count', '1');
  end;
  
  // Set Flag
  if enableSetFlags then begin
    flags := ElementByPath(e, 'ACBS - Configuration');
    if Assigned(flags) then begin
      SetElementEditValues(flags, 'Flags\Respown', 0);
      SetElementEditValues(flags, 'Flags\Unique', 1);
      SetElementEditValues(flags, 'Flags\looped script?', 0);
      SetElementEditValues(flags, 'Flags\PC Level Mult', 1);
      SetElementEditValues(flags, 'Flags\Auto-calc stats', 1);
      SetElementEditValues(flags, 'Flags\Opposite Gender Anims', 0);
      SetElementEditValues(flags, 'Flags\looped audio?', 0);
    end;
  end;
  
  // Essential / Protected settings
  if enableSetEssentialProtected then begin
    if Assigned(flags) then begin
      SetElementEditValues(flags, 'Flags\Essential', defaultEssential);
      SetElementEditValues(flags, 'Flags\Protected', defaultProtected);
    end;
  end;
  
  // Modify Faction
  if enableSetFactions then begin
    // If a Factions element exists, delete it and clear the Factions element
    factions := ElementByPath(e, 'Factions');
    if Assigned(factions) then
      RemoveElement(e, 'Factions');
    
    // Add a new Factions element and delete the null faction that was automatically added
    factions := Add(e, 'Factions', True);
    RemoveElement(factions, ElementByIndex(factions, 0));
    
    // Add PotentialMarriageFaction
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(potMarriageFac), 8));
    
    // Add PotentialFollowerFaction
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(potFollowerFac), 8));
    
    // Add CurrentFollowerFaction, set rank to -1
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(curFollowerFac), 8));
    SetElementEditValues(newFaction, 'Rank', '-1');
  end;
  
  // Add Perks
  // TODO:Avoid adding duplicate parks
  if enableAddPerks then begin
    perks := ElementByPath(e, 'Perks');
    if not Assigned(perks) then begin
      perks := Add(e, 'Perks', True);
      RemoveElement(perks, ElementByIndex(perks, 0));
    end;
    newPerk := ElementAssign(perks, HighInteger, nil, False);
    SetElementEditValues(newPerk, 'Perk', IntToHex(GetLoadOrderFormID(addPerk), 8));
  end;

  // Add Relationship record
  if enableAddRelationship then begin
    relEditorID := NPCEditorID + 'Rel';
    relRecordGroup := GroupBySignature(GetFile(e), 'RELA');
    existRelRec := MainRecordByEditorID(relRecordGroup, relEditorID);
    // Do nothing if a Relationship record related to the selected NPC already exists
    if Assigned(existRelRec) then
        AddMessage('A Relationship record for this NPC already exists.')
    else begin
      // Since we can't add a record normally, we copy the Relationship record in Skyrim.esm
      // Refer to HousecarlWhiterunPlayerRelationship as the source to copy
      baseRel := RecordByFormID(FileByIndex(0), LYDIA_PLAYER_RELATIONSHIP, True);
      rel := wbCopyElementToFile(baseRel, GetFile(e), True, True);
      if not Assigned(rel) then
      begin
        AddMessage('Failed to add Relationship record.');
        Result := 1;
        Exit;
      end;
      
      // Change the Editor ID of the Relationship record based on the Editor ID of the NPC record
      SetElementEditValues(rel, 'EDID', relEditorID);

      // Set the parent.
      SetElementEditValues(rel, 'DATA\Parent', IntToHex(GetLoadOrderFormID(e), 8));

      // Set the relationship rank (4: Acquaintance, 2: Confidant, 3: Friend, 1: Ally, 0: Lover).
      // It seems like the numbers in the game and the numbers set in the record are different. Confusing.
      SetElementEditValues(rel, 'DATA\Rank', '3'); // Friend is 3

      AddMessage('Added a Relationship record: ' + Name(e) + ' -> Player');
    end;
  end;

  // Get the location of the NPC to be replaced and place it in the same location
  // TODO:Output the FormID and EditorID of the failed NPC record to a .txt file
  if enableAddHomeLocation then begin
    newNPCPlaced := false;
    // Skip if ACHR record already exists
    AddMessage('Check if this NPC is already placed...');
    NPC_ACHRRecord := FindNPCPlacedRecord(e);
    if Assigned(NPC_ACHRRecord) then begin
      AddMessage('The NPC is already placed.');
      newNPCPlaced := true;
    end
    else
      AddMessage('The NPC is not placed.');
    
    // File scanning loop
    for i := fileSearchOffset to FileCount - 2 do begin
      if newNPCPlaced then
        break;
      // Exclude Update from scanning
      if i = 1 then
        continue;
      // Narrow the scanning target to NPC group records
      baseFile := FileByLoadOrder(i);
       //AddMessage('Serching target file name: ' + GetFileName(baseFile));
      npcRecordGroup := GroupBySignature(baseFile, 'NPC_');
      
      // Get the NPC record that was originally replaced
      baseNPCRecord := MainRecordByEditorID(npcRecordGroup, baseNPCEditorID);
      
      if Assigned(baseNPCRecord) then begin
        // Detect ACHR (NPC placement) record
        AddMessage('Check original NPC placement record...');
        refCell := FindNPCPlacedRecord(baseNPCRecord);
        // Copy the found record
        newCell := wbCopyElementToFile(refCell, GetFile(e), True, True);
        // If the cell copy is successful, make various changes and move on to the next NPC record
        if Assigned(newCell) then begin
          SetIsPersistent(newCell, true);
          SetIsInitiallyDisabled(newCell, false);
          SetElementEditValues(newCell, 'EDID', EditorID(e) + 'Ref');
          SetEditValue(ElementByPath(newCell, 'NAME'), GetEditValue(e));
          AddMessage(Format('Copied Cell NPC Editor ID: %s, Record Editor ID: %s', [GetElementEditValues(newCell, 'NAME'), GetElementEditValues(newCell, 'EDID')]));
          AddMessage('The NPC was successfully placed.');
          newNPCPlaced := true;
        end;
      end;
    end;
    if newNPCPlaced = false then
      AddMessage('Failed to place NPC.');
  end;
  
  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
