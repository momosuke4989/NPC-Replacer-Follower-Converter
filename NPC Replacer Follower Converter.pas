unit userscript;

interface
implementation
uses xEditAPI, SysUtils, StrUtils, Windows;

const
  // Turn each change on/off
  DISABLE_USE_TRAITS_TEMPLATE_NPC = True;
  
  ENABLE_SET_VMADS = True;
  ENABLE_SET_AI_PACKAGES = True;
  ENABLE_SET_COMBAT_STYLE = True;
  ENABLE_SET_NAME = True;
  ENABLE_SET_OUTFIT = True;
  ENABLE_SET_INVETORY = True;
  ENABLE_SET_FLAGS = True;
  ENABLE_SET_VOICE = True;
  ENABLE_SET_ESSENTIAL_PROTECTED = True;
  ENABLE_SET_FACTIONS = True;
  
  ENABLE_ADD_PERKS = True;
  ENABLE_ADD_RELATIONSHIP = True;
  ENABLE_ADD_HOME_LOCATION = True;
  
  // Constants related to searching for cells to place NPCs
  SERCH_EXCLUDE_VANILLA_FILES = False;  // Whether to search for vanilla game files
  MAX_SERCH_FILES_COUNT = 30;           // Maximum number of plugin files loaded

  // Default value for each change. Specify by Form ID
  DEFAULT_WEAPON_ITEM = $0001397E;            // 0001397E Iron Dagger
  DEFAULT_AI_PACKAGE = $0001B217;             // 0001B217 DefaultSandboxEditorLocation512
  DEFAULT_COMBAT_STYLE = $0003BE1B;           // 0003BE1B csHumanMeleeLvl1
  DEFAULT_OUTFIT = $0009D5DF;                 // 0009D5DF FarmClothesOutfit04
  DEFAULT_FOLLOWER_VOICE_MALE = $00013AD2;    // 00013AD2 MaleEvenToned
  DEFAULT_FOLLOWER_VOICE_FEMALE = $00013ADD;  // 00013ADD FemaleEvenToned
  
 // Set the Protected/Essential flag. Only one of them can be turned on.
  DEFAULT_PROTECTED = '1';
  DEFAULT_ESSENTIAL = '0';

  // Used to reference the source of a Relationship record. Change prohibited
  POTENTIAL_MARRIAGE_FACTION = $00019809;
  POTENTIAL_FOLLOWER_FACTION = $0005C84D;
  CURRENT_FOLLOWER_FACTION = $0005C84E;
  LYDIA_PLAYER_RELATIONSHIP = $00103AED;
  PERK_LIGHT_FOOT = $0005820C;
var
  potMarriageFac, potFollowerFac, curFollowerFac: IwbMainRecord;
  defaultWeaponItem, defaultAIPackage, defaultCombatStyle, defaultOutfit, defaultFollowerVoiceMale, defaultFollowerVoiceFemale, addPerk: IwbMainRecord;
  fileSearchOffset: Integer;

function Initialize: integer;
begin
  Result := 0;
  
  // Set record variables
  potMarriageFac := RecordByFormID(FileByIndex(0), POTENTIAL_MARRIAGE_FACTION, True);
  potFollowerFac := RecordByFormID(FileByIndex(0), POTENTIAL_FOLLOWER_FACTION, True);
  curFollowerFac := RecordByFormID(FileByIndex(0), CURRENT_FOLLOWER_FACTION, True);
  
  defaultWeaponItem := RecordByFormID(FileByIndex(0), DEFAULT_WEAPON_ITEM, True);
  defaultAIPackage := RecordByFormID(FileByIndex(0), DEFAULT_AI_PACKAGE, True);
  defaultCombatStyle := RecordByFormID(FileByIndex(0), DEFAULT_COMBAT_STYLE, True);
  defaultOutfit := RecordByFormID(FileByIndex(0), DEFAULT_OUTFIT, True);
  defaultFollowerVoiceMale := RecordByFormID(FileByIndex(0), DEFAULT_FOLLOWER_VOICE_MALE, True);
  defaultFollowerVoiceFemale := RecordByFormID(FileByIndex(0), DEFAULT_FOLLOWER_VOICE_FEMALE, True);
  
  addPerk := RecordByFormID(FileByIndex(0), PERK_LIGHT_FOOT, True);
  
  if ENABLE_ADD_HOME_LOCATION then begin
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
end;

function Process(e: IInterface): integer;
var
  vmad, factions, newFaction, aiPackages, newAiPackage, perks, newPerk, combatStyle, voice, outfit, inventory, newItem, itemRecord, flags: IInterface;
  relrecordGroup, npcRecordGroup: IwbGroupRecord;
  existRelRec, baseNPCRecord, refCell, newCell, baseRel, rel: IwbMainRecord;
  baseFile : IwbFile;
  NPCEditorID, baseNPCEditorID, npcName, relEditorID, itemType: string;
  i, j, underscorePos, useTraitsFlag: integer;
begin
  // Process only NPC records
  if Signature(e) <> 'NPC_' then Exit;

  AddMessage('Modifying NPC: ' + EditorID(e));
  
  // Depending on the option, NPCs with the UseTraits flag will skip processing.
  if DISABLE_USE_TRAITS_TEMPLATE_NPC then begin
    useTraitsFlag := GetElementNativeValues(ElementBySignature(e, 'ACBS'), 'Template Flags');
    if (useTraitsFlag and $01) <> 0 then begin
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
  if ENABLE_SET_VMADS then begin
    vmad := ElementBySignature(e, 'VMAD');
    if Assigned(vmad) then
      RemoveElement(e, 'VMAD');
  end;

  // Set AI package
  if ENABLE_SET_AI_PACKAGES then begin
    aiPackages := ElementByPath(e, 'Packages');
    if Assigned(aiPackages) then
      RemoveElement(e, 'Packages');
    
    aiPackages := Add(e, 'Packages', True);
    RemoveElement(aiPackages, ElementByIndex(aiPackages, 0));
    
    newAiPackage := ElementAssign(aiPackages, HighInteger, nil, False);
    SetEditValue(newAiPackage, IntToHex(GetLoadOrderFormID(defaultAIPackage), 8));
  end;

  // Set Combat Style
  if ENABLE_SET_COMBAT_STYLE then begin
    if GetElementEditValues(e, 'ZNAM') = '' then
      begin
        // Get or create Combat Style element
        if not Assigned(ElementByPath(e, 'ZNAM')) then
          Add(e, 'ZNAM', True);
        SetElementEditValues(e, 'ZNAM', IntToHex(GetLoadOrderFormID(defaultCombatStyle), 8));
      end
  end;
  
  // Set name
  if ENABLE_SET_NAME then begin
    npcName := GetElementEditValues(e, 'FULL');
    // If name is blank, assign it the Editor ID to replace
    if npcName = '' then
      npcName := baseNPCEditorID;
    // Add prefix after default name
    npcName := npcName + ' [' + Copy(NPCEditorID, 0, underscorePos - 1) + ']';
    SetElementEditValues(e, 'FULL', npcName);
  end;

  // Set voice type
  if ENABLE_SET_VOICE then begin
    voice := ElementByPath(e, 'VTCK - Voice');
    if not Assigned(voice) then begin
      Add(e, 'VTCK', True);
      if GetElementEditValues(flags, 'Flags\Female', 1) then
        SetElementEditValues(e, 'VTCK - Voice', IntToHex(GetLoadOrderFormID(defaultFollowerVoiceFemale), 8))
      else
        SetElementEditValues(e, 'VTCK - Voice', IntToHex(GetLoadOrderFormID(defaultFollowerVoiceMale), 8));
    end;
  end;

  // Set Outfit
  if ENABLE_SET_OUTFIT then begin
    outfit := ElementBySignature(e, 'DOFT');
    if not Assigned(outfit) then
      Add(e, 'DOFT', True);
    SetElementEditValues(e, 'DOFT', IntToHex(GetLoadOrderFormID(defaultOutfit), 8));
  end;
  
  // Set Items
  if ENABLE_SET_INVETORY then begin
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
  if ENABLE_SET_FLAGS then begin
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
  if ENABLE_SET_ESSENTIAL_PROTECTED then begin
    if Assigned(flags) then begin
      SetElementEditValues(flags, 'Flags\Essential', DEFAULT_ESSENTIAL);
      SetElementEditValues(flags, 'Flags\Protected', DEFAULT_PROTECTED);
    end;
  end;
  
  
  // Modify Faction
  if ENABLE_SET_FACTIONS then begin
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
  if ENABLE_ADD_PERKS then begin
    perks := ElementByPath(e, 'Perks');
    if not Assigned(perks) then begin
      perks := Add(e, 'Perks', True);
      RemoveElement(perks, ElementByIndex(perks, 0));
    end;
    newPerk := ElementAssign(perks, HighInteger, nil, False);
    SetElementEditValues(newPerk, 'Perk', IntToHex(GetLoadOrderFormID(addPerk), 8));
  end;

  // Add Relationship record
  if ENABLE_ADD_RELATIONSHIP then begin
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
      SetElementEditValues(rel, 'DATA\Rank', '3'); // 3はFriendを示す

      AddMessage('Added a Relationship record: ' + Name(e) + ' -> Player');
    end;
  end;

  // Get the location of the NPC to be replaced and place it in the same location
  if ENABLE_ADD_HOME_LOCATION then begin
    // File scanning loop
    for i := fileSearchOffset to FileCount - 2 do
    begin
      // Exclude Update from scanning
      if i = 1 then
        continue;
      // Narrow the scanning target to NPC group records
      baseFile := FileByLoadOrder(i);
       //AddMessage('Serching target file name: ' + GetFileName(baseFile));
      npcRecordGroup := GroupBySignature(baseFile, 'NPC_');
      
      // Get the NPC record that was originally replaced
      baseNPCRecord := MainRecordByEditorID(npcRecordGroup, baseNPCEditorID);
      
      for j := 0 to Pred(ReferencedByCount(baseNPCRecord)) do
      begin
        // Scan for records that reference the replaced NPC record
        refCell := ReferencedByIndex(baseNPCRecord, j);
        //AddMessage(IntToStr(j) + '. RefernceRecord Signature: ' + Signature(refCell));
        // Detect ACHR (NPC placement) record
        if Signature(refCell) = 'ACHR' then
        begin
          // Copy the found record
          newCell := wbCopyElementToFile(refCell, GetFile(e), True, True);
          // If the cell copy is successful, make various changes and move on to the next NPC record
          if Assigned(newCell) then begin
            SetIsPersistent(newCell, true);
            SetIsInitiallyDisabled(newCell, false);
            SetElementEditValues(newCell, 'EDID', EditorID(e) + 'Ref');
            SetEditValue(ElementByPath(newCell, 'NAME'), GetEditValue(e));
            AddMessage(Format('Copied Cell NPC Editor ID: %s, Record Editor ID: %s', [GetElementEditValues(newCell, 'NAME'), GetElementEditValues(newCell, 'EDID')]));
            Exit;
          end
          else
            AddMessage('Failed to copy cell.');
        end;
      end;
    end;
  end;
  
  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
