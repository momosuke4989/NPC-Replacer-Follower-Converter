unit userscript;

interface
implementation
uses xEditAPI, SysUtils, StrUtils, Windows;

const
  // 各変更のオン/オフ
  ENABLE_SET_VMADS = True;
  ENABLE_SET_FACTIONS = True;
  ENABLE_SET_AI_PACKAGES = True;
  ENABLE_SET_VOICE = True;
  ENABLE_SET_OUTFIT = True;
  ENABLE_SET_ESSENTIAL_PROTECTED = True;
  ENABLE_SET_HOME_LOCATION = True;

  // 変更する値
  DEFAULT_FOLLOWER_VOICE = 'MaleEvenToned';
  DEFAULT_PROTECTED = '1';
  DEFAULT_ESSENTIAL = '0';

var
  PlayerRef, potMarriageFac, potFollowerFac, curFollowerFac : IInterface;

function IsMasterAEPlugin(plugin: IInterface): Boolean;
var
  PluginName  : String;
Begin
  PluginName := GetFileName(plugin);
  Result := (CompareStr(PluginName, 'Skyrim.esm') = 0) or (CompareStr(PluginName, 'Update.esm') = 0) or (CompareStr(PluginName, 'Dawnguard.esm') = 0) or (CompareStr(PluginName, 'HearthFires.esm') = 0) or (CompareStr(PluginName, 'Dragonborn.esm') = 0) or (CompareStr(PluginName, 'ccBGSSSE001-Fish.esm') = 0) or (CompareStr(PluginName, 'ccQDRSSE001-SurvivalMode.esl') = 0) or (CompareStr(PluginName, 'ccBGSSSE037-Curios.esl') = 0) or (CompareStr(PluginName, 'ccBGSSSE025-AdvDSGS.esm') = 0) or (CompareStr(PluginName, '_ResourcePack.esl') = 0);
End;

function GetNPCRecordCount(aFile: IwbFile): Cardinal;
var
  i, count: Cardinal;
  rec:  IInterface;
  group: IwbGroupRecord;
begin
  count := 0;
  group := GroupBySignature(aFile, 'NPC_');
  
  // グループが存在する場合
  if Assigned(group) then begin
    // グループ内のレコード数を取得
    for i := 0 to ElementCount(group) - 1 do begin
      rec := ElementByIndex(group, i);
      // レコードが 'NPC_' シグネチャを持つか確認
      if Signature(rec) = 'NPC_' then
        Inc(count);
    end;
  end;
  
  Result := count;
end;

function Initialize: integer;
begin
  Result := 0;
  PlayerRef := RecordByFormID(FileByIndex(0), $00000007, True);
  potMarriageFac := RecordByFormID(FileByIndex(0), $00019809, True);
  potFollowerFac := RecordByFormID(FileByIndex(0), $0005C84D, True);
  curFollowerFac := RecordByFormID(FileByIndex(0), $0005C84E, True);
  
end;

function Process(e: IInterface): integer;
var
  vmad, factions, newFaction, aiPackages, voice, outfit, flags, refRel, rel: IInterface;
  recordGroup: IwbGroupRecord;
  existRelRec: IwbMainRecord;
  relEditorID: string;
begin
  // NPCレコードのみ処理
  if Signature(e) <> 'NPC_' then Exit;

  AddMessage('Modifying NPC: ' + Name(e));


  // クエストスクリプトの削除
  if ENABLE_SET_VMADS then begin
    vmad := ElementBySignature(e, 'VMAD');
    if Assigned(vmad) then
      RemoveElement(e, 'VMAD');
  end;

  // AI パッケージの修正
  if ENABLE_SET_AI_PACKAGES then begin
    aiPackages := ElementByPath(e, 'AI Data\Packages');
    if Assigned(aiPackages) then
      RemoveElement(e, 'AI Data\Packages');
    SetElementEditValues(e, 'AI Data\Template Flags', 'Use Default AI');
  end;

  // Faction の修正
  if ENABLE_SET_FACTIONS then begin
    factions := ElementByPath(e, 'Factions');
    if Assigned(factions) then
      RemoveElement(e, 'Factions');
   
    factions := Add(e, 'Factions', True);
    RemoveElement(factions, ElementByIndex(factions, 0));
    
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(potMarriageFac), 8));
    
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(potFollowerFac), 8));
    
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(curFollowerFac), 8));
    SetElementEditValues(newFaction, 'Rank', '-1');
    

  end;

{
  // ボイスタイプの設定
  if ENABLE_SET_VOICE then begin
    voice := ElementByPath(e, 'VTCK - Voice');
    if Assigned(voice) then
      SetElementEditValues(e, 'VTCK - Voice', DEFAULT_FOLLOWER_VOICE);
  end;
}
  // 所持品と Outfit の設定
  if ENABLE_SET_OUTFIT then begin
    outfit := ElementBySignature(e, 'DOFT');
    if Assigned(outfit) then
      RemoveElement(e, 'DOFT');
  end;

  // Essential / Protected の設定
  if ENABLE_SET_ESSENTIAL_PROTECTED then begin
    flags := ElementByPath(e, 'ACBS - Configuration');
    if Assigned(flags) then begin
      SetElementEditValues(flags, 'Flags\Essential', DEFAULT_ESSENTIAL);
      SetElementEditValues(flags, 'Flags\Protected', DEFAULT_PROTECTED);
    end;
  end;


  // Relationshipレコードを追加
  // 選択中のNPCに関連するRelationshipレコードがすでに存在していたら何もしない
  relEditorID := GetElementEditValues(e, 'EDID') + 'Rel';
  recordGroup := GroupBySignature(GetFile(e), 'RELA');
  existRelRec := MainRecordByEditorID(recordGroup, relEditorID);
  if Assigned(existRelRec) then
      AddMessage('A Relationship record for this NPC already exists.')
  else begin
    // 普通にレコードを追加できないので、Skyrim.esm内のRelationshipレコードをコピーする
    // HousecarlWhiterunPlayerRelationshipをコピー元として参照する
    refRel := RecordByFormID(FileByIndex(0), $00103AED, True);
    rel := wbCopyElementToFile(refRel, GetFile(e), True, True);
    if not Assigned(rel) then
    begin
      AddMessage('Failed to add Relationship record.');
      Result := 1;
      Exit;
    end;
    
    // RelationshipレコードのEditor IDをNPCレコードのEditor IDをベースに変更
    SetElementEditValues(rel, 'EDID', relEditorID);

    // 親（Parent）を設定
    SetElementEditValues(rel, 'DATA\Parent', IntToHex(GetLoadOrderFormID(e), 8));

    // 関係性のランクを設定（4: Acquaintance, 2: Confidant, 3: Friend, 1: Ally, 0: Lover）
    // どうやらゲーム内の数値とレコードで設定する数値が異なっているようだ。ややこしい。
    SetElementEditValues(rel, 'DATA\Rank', '3'); // 3はFriendを示す

    AddMessage('Added a Relationship record: ' + Name(e) + ' -> Player');
  end;

  
  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
