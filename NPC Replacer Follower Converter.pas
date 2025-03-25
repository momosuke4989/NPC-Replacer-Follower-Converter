unit userscript;

interface
implementation
uses xEditAPI, SysUtils, StrUtils, Windows;

const
  // 各変更のオン/オフ
  ENABLE_REMOVE_VMADS = True;
  ENABLE_REMOVE_FACTIONS = True;
  ENABLE_ADD_FACTIONS = True;
  ENABLE_REMOVE_AI_PACKAGES = True;
  ENABLE_SET_VOICE = True;
  ENABLE_REMOVE_OUTFIT = True;
  ENABLE_SET_ESSENTIAL_PROTECTED = True;

  // 変更する値
  DEFAULT_FOLLOWER_VOICE = 'MaleEvenToned';
  DEFAULT_PROTECTED = '1';
  DEFAULT_ESSENTIAL = '0';

var
  NPC: IInterface;

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
end;

function Process(e: IInterface): integer;
var
  vmad, factions, aiPackages, voice, outfit, flags: IInterface;
begin
  // NPCレコードのみ処理
  if Signature(e) <> 'NPC_' then Exit;

  AddMessage('Modifying NPC: ' + Name(e));
  NPC := e;

  // クエストスクリプトの削除
  if ENABLE_REMOVE_VMADS then begin
    vmad := ElementBySignature(NPC, 'VMAD');
    if Assigned(vmad) then
      RemoveElement(NPC, 'VMAD');
  end;

  // AI パッケージの修正
  if ENABLE_REMOVE_AI_PACKAGES then begin
    aiPackages := ElementByPath(NPC, 'AI Data\Packages');
    if Assigned(aiPackages) then
      RemoveElement(NPC, 'AI Data\Packages');
    SetElementEditValues(NPC, 'AI Data\Template Flags', 'Use Default AI');
  end;

  // Faction の修正
  if ENABLE_REMOVE_FACTIONS then begin
    factions := ElementByPath(NPC, 'Factions');
    if Assigned(factions) then
      RemoveElement(NPC, 'Factions');
  end;

  if ENABLE_ADD_FACTIONS then begin
    Add(NPC, 'Factions', True);
    AddFaction(NPC, 'PlayerFaction', 0);  // フォロワーとして認識
    AddFaction(NPC, 'PotentialFollowerFaction', 0);  // 勧誘可能に
  end;

  // ボイスタイプの設定
  if ENABLE_SET_VOICE then begin
    voice := ElementByPath(NPC, 'VTCK - Voice');
    if Assigned(voice) then
      SetElementEditValues(NPC, 'VTCK - Voice', DEFAULT_FOLLOWER_VOICE);
  end;

  // 所持品と Outfit の設定
  if ENABLE_REMOVE_OUTFIT then begin
    outfit := ElementBySignature(NPC, 'DOFT');
    if Assigned(outfit) then
      RemoveElement(NPC, 'DOFT');
  end;

  // Essential / Protected の設定
  if ENABLE_SET_ESSENTIAL_PROTECTED then begin
    flags := ElementByPath(NPC, 'ACBS - Configuration');
    if Assigned(flags) then begin
      SetElementEditValues(flags, 'Flags\Essential', DEFAULT_ESSENTIAL);
      SetElementEditValues(flags, 'Flags\Protected', DEFAULT_PROTECTED);
    end;
  end;

  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
