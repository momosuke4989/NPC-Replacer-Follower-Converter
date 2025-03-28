unit userscript;

interface
implementation
uses xEditAPI, SysUtils, StrUtils, Windows;

const
  // 各変更のオン/オフ
  ENABLE_SET_VMADS = True;
  ENABLE_SET_AI_PACKAGES = True;
  ENABLE_SET_COMBAT_STYLE = True;
  ENABLE_SET_OUTFIT = True;
  ENABLE_SET_INVETORY = True;
  ENABLE_SET_VOICE = True;
  ENABLE_SET_ESSENTIAL_PROTECTED = True;
  ENABLE_SET_FACTIONS = True;
  ENABLE_SET_HOME_LOCATION = True;

  // 変更する値
  DEFAULT_AI_PACKAGE = $0001B217;
  DEFAULT_COMBAT_STYLE = $0003BE1B;
  DEFAULT_OUTFIT = $0009D5DF;
  DEFAULT_FOLLOWER_VOICE = 'MaleEvenToned';
  DEFAULT_PROTECTED = '1';
  DEFAULT_ESSENTIAL = '0';

  LYDIA_PLAYER_RELATIONSHIP = $00103AED;
var
  PlayerRef, potMarriageFac, potFollowerFac, curFollowerFac, defaultAIPackage, defaultCombatStyle, defaultOutfit : IInterface;

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
  
  defaultAIPackage := RecordByFormID(FileByIndex(0), DEFAULT_AI_PACKAGE, True);
  defaultCombatStyle := RecordByFormID(FileByIndex(0), DEFAULT_COMBAT_STYLE, True);
  defaultOutfit := RecordByFormID(FileByIndex(0), DEFAULT_OUTFIT, True);
  
end;

function Process(e: IInterface): integer;
var
  vmad, factions, newFaction, aiPackages, newAiPackage, combatStyle, voice, outfit, inventory, item, itemRecord, flags: IInterface;
  relrecordGroup, npcRecordGroup: IwbGroupRecord;
  existRelRec, baseNPCRecord, refCell, newCell, refRel, rel: IwbMainRecord;
  targetFile : IwbFile;
  NPCEditorID, baseNPCEditorID, relEditorID, itemType: string;
  i, j, underscorePos, maxfile: integer;
  SEflag: boolean;
begin
  // NPCレコードのみ処理
  if Signature(e) <> 'NPC_' then Exit;

  AddMessage('Modifying NPC: ' + Name(e));

  NPCEditorID := GetElementEditValues(e, 'EDID');
  
  // クエストスクリプトの削除
  if ENABLE_SET_VMADS then begin
    vmad := ElementBySignature(e, 'VMAD');
    if Assigned(vmad) then
      RemoveElement(e, 'VMAD');
  end;

  // AI パッケージの修正
  if ENABLE_SET_AI_PACKAGES then begin
    aiPackages := ElementByPath(e, 'Packages');
    if Assigned(aiPackages) then
      RemoveElement(e, 'Packages');
    
    aiPackages := Add(e, 'Packages', True);
    RemoveElement(aiPackages, ElementByIndex(aiPackages, 0));
    
    newAiPackage := ElementAssign(aiPackages, HighInteger, nil, False);
    SetEditValue(newAiPackage, IntToHex(GetLoadOrderFormID(defaultAIPackage), 8));
  end;

  // combat styleの設定
  if ENABLE_SET_COMBAT_STYLE then begin
    if GetElementEditValues(e, 'ZNAM') = '' then
      begin
        // Combat Styleエレメントを取得または作成
        if not Assigned(ElementByPath(e, 'ZNAM')) then
          Add(e, 'ZNAM', True);

        // Combat Styleを設定
        SetElementEditValues(e, 'ZNAM', IntToHex(GetLoadOrderFormID(defaultCombatStyle), 8));
      end
  end;
{
  // ボイスタイプの設定
  if ENABLE_SET_VOICE then begin
    voice := ElementByPath(e, 'VTCK - Voice');
    if Assigned(voice) then
      SetElementEditValues(e, 'VTCK - Voice', DEFAULT_FOLLOWER_VOICE);
  end;
}
  // Outfit の設定
  if ENABLE_SET_OUTFIT then begin
    outfit := ElementBySignature(e, 'DOFT');
    if not Assigned(outfit) then
      Add(e, 'DOFT', True);
    SetElementEditValues(e, 'DOFT', IntToHex(GetLoadOrderFormID(defaultOutfit), 8));
  end;
  
  // Itemsの設定
  if ENABLE_SET_INVETORY then begin
    // インベントリリストを取得
    inventory := ElementByPath(e, 'Items');
    if Assigned(inventory) then
      RemoveElement(e, 'Items');
  end;
  
  // Flagの設定
  flags := ElementByPath(e, 'ACBS - Configuration');
  if Assigned(flags) then begin
    SetElementEditValues(flags, 'Flags\Unique', 1);
    SetElementEditValues(flags, 'Flags\looped script?', 0);
    SetElementEditValues(flags, 'Flags\PC Level Mult', 1);
    SetElementEditValues(flags, 'Flags\Auto-calc stats', 1);
  end;
  
  // Essential / Protected の設定
  if ENABLE_SET_ESSENTIAL_PROTECTED then begin
    if Assigned(flags) then begin
      SetElementEditValues(flags, 'Flags\Essential', DEFAULT_ESSENTIAL);
      SetElementEditValues(flags, 'Flags\Protected', DEFAULT_PROTECTED);
    end;
  end;
  
  
  // Faction の修正
  if ENABLE_SET_FACTIONS then begin
    // Factionsエレメントが存在していた場合、削除してFactionsエレメントをクリアにする
    factions := ElementByPath(e, 'Factions');
    if Assigned(factions) then
      RemoveElement(e, 'Factions');
    
    // Factionsエレメントを新規追加、自動で追加されたnull Factionを削除
    factions := Add(e, 'Factions', True);
    RemoveElement(factions, ElementByIndex(factions, 0));
    
    // PotentialMarriageFactionを追加
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(potMarriageFac), 8));
    
    // PotentialFollowerFactionを追加
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(potFollowerFac), 8));
    
    // CurrentFollowerFactionを追加、ランクを-1に設定
    newFaction := ElementAssign(factions, HighInteger, nil, False);
    SetElementEditValues(newFaction, 'Faction', IntToHex(GetLoadOrderFormID(curFollowerFac), 8));
    SetElementEditValues(newFaction, 'Rank', '-1');
  end;

  // Relationshipレコードを追加
  // 選択中のNPCに関連するRelationshipレコードがすでに存在していたら何もしない
  relEditorID := NPCEditorID + 'Rel';
  relRecordGroup := GroupBySignature(GetFile(e), 'RELA');
  existRelRec := MainRecordByEditorID(relRecordGroup, relEditorID);
  if Assigned(existRelRec) then
      AddMessage('A Relationship record for this NPC already exists.')
  else begin
    // 普通にレコードを追加できないので、Skyrim.esm内のRelationshipレコードをコピーする
    // HousecarlWhiterunPlayerRelationshipをコピー元として参照する
    refRel := RecordByFormID(FileByIndex(0), LYDIA_PLAYER_RELATIONSHIP, True);
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

  // 配置する場所を設定
  if ENABLE_SET_HOME_LOCATION then begin
    // リプレイス先NPCの配置場所を取得し、同じ場所に配置する
    // TODO:バニラ以外のリプレイサーの初期配置の方法をどうにかしたい
    // ゲーム本体のバージョンに応じて走査するバニラファイルの数を設定
    SEflag := false;
    if SEflag then
      maxfile := 4
    else
      maxfile := 8;
    
    // EditorIDから本来のリプレイス先となるNPCのEditorIDを取得
    underscorePos := LastDelimiter('_', NPCEditorID);
    baseNPCEditorID := Copy(NPCEditorID, underscorePos + 1, Length(NPCEditorID) - underscorePos);
    //AddMessage('Base NPC Editor ID: ' + baseNPCEditorID);
    
    // バニラファイルすべてを走査する
    for i := 0 to maxfile do
    begin
      // Update, SuvivalMode, Curiosは走査から除外
      if i = 1 or i = 6 or i = 7 then
        continue;
      // 走査対象をNPCグループレコードに絞る
      targetFile := FileByLoadOrder(i);
      // AddMessage('Target file name: ' + GetFileName(targetFile));
      npcRecordGroup := GroupBySignature(targetFile, 'NPC_');
      
      // 本来リプレイスしていたNPCレコードを取得
      baseNPCRecord := MainRecordByEditorID(npcRecordGroup, baseNPCEditorID);
      
      for j := 0 to Pred(ReferencedByCount(baseNPCRecord)) do
      begin
        // リプレイスしていたNPCレコードを参照しているレコードを走査
        refCell := ReferencedByIndex(baseNPCRecord, j);
        //AddMessage(IntToStr(j) + '. RefernceRecord Signature: ' + Signature(refCell));
        // ACHR(NPC配置)レコードを検出
        if Signature(refCell) = 'ACHR' then
        begin
          // 検出したレコードをコピー
          newCell := wbCopyElementToFile(refCell, GetFile(e), True, True);
          // セルのコピーに成功したら色々変更して次のNPCレコードへ
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
