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
  PlayerRef: IInterface;

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
end;

function Process(e: IInterface): integer;
var
  vmad, factions, aiPackages, voice, outfit, flags, refrel, rel: IInterface;
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
    
    Add(e, 'Factions', True);
//    SetElementEditValues(e, 'Factions', 'PotentialFollowerFaction');
    
//    SetElementEditValues(e, 'Factions', 'CurrentFollowerFaction');
    
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
  refrel := RecordByFormID(FileByIndex(0), $00103AED, True);
  rel := wbCopyElementToFile(refrel, GetFile(e), True, True);
  if not Assigned(rel) then
  begin
    AddMessage('Failed to add Relationship record.');
    Result := 1;
    Exit;
  end;

  // 親（Parent）を設定
  SetElementEditValues(rel, 'Parent', Name(e));

  // 子（Child）を設定
  SetElementEditValues(rel, 'Child', Name(PlayerRef));

  // 関係性のランクを設定（0: Acquaintance, 1: Confidant, 2: Friend, 3: Ally, 4: Lover）
  SetElementEditValues(rel, 'Rank', '2'); // 2はFriendを示す

  AddMessage('Added a Relationship record: ' + Name(e) + ' -> Player');

  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
