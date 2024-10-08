Autologin_Table = {}
Autologin_SelectedIdx = nil;
Autologin_CurrentPage = 0;
Autologin_PageSize = 4;
Autologin_LimitReached = false;

function Autologin_Load()
  Autologin_Table = {};
  local val = GetSavedAccountName()
  for n, p, c in string.gfind(val, "(%S+) (%S+) *(%d*);") do
    if (c == "") then c = "-" end

    -- Decompress duplicate passwords
    if (string.find(p, "~%d") == 1) then
      p = Autologin_Table[tonumber(string.sub(p, 2, 3))].password;
    end

    table.insert(Autologin_Table, { name = n, password = p, character = c });
  end
end

function Autologin_Save(name, password)
  -- Add/update name and password in table
  if (name ~= nil and name ~= "" and password ~= nil and password ~= "") then
    local exists = false;
    for i = 1, table.getn(Autologin_Table) do
      if (Autologin_Table[i].name == name) then
        exists = true;
        Autologin_Table[i].password = password;
      end
    end
    if (not exists) then
      table.insert(Autologin_Table,
                   { name = name, password = password, character = "-" });
    end
  end

  -- If table is empty, reset saved var
  if (table.getn(Autologin_Table) == 0) then
    SetSavedAccountName('');
    return;
  end

  -- Serialize table to saved var
  local savedVar = "";
  for i = 1, table.getn(Autologin_Table) do
    local r = Autologin_Table[i];

    -- Compress duplicate passwords
    local pw = r.password;
    for j = 1, i - 1 do
      if (Autologin_Table[j].password == r.password) then pw = '~' .. j end
    end

    savedVar = savedVar .. r.name .. ' ' .. pw;
    if (r.character == "-") then
      savedVar = savedVar .. ";";
    else
      savedVar = savedVar .. ' ' .. r.character .. ';';
    end
  end

  Autologin_LimitReached = string.len(savedVar) > 128;
  SetSavedAccountName(savedVar);
end

function Autologin_SelectAccount(idx)
  local i = Autologin_CurrentPage * Autologin_PageSize + idx;
  AccountLoginAccountEdit:SetText(Autologin_Table[i].name);
  AccountLoginPasswordEdit:SetText(Autologin_Table[i].password);
end

function Autologin_OnNameUpdate(name)
  Autologin_SelectedIdx = nil;
  for i = 1, table.getn(Autologin_Table) do
    if (Autologin_Table[i].name == name) then Autologin_SelectedIdx = i; end
  end
  if (Autologin_SelectedIdx) then
    Autologin_CurrentPage = math.floor((Autologin_SelectedIdx - 1) /
                                           Autologin_PageSize);
  end
  Autologin_UpdateUI();
end

function Autologin_UpdateUI()
  local skip = Autologin_CurrentPage * Autologin_PageSize;
  for i = 1, Autologin_PageSize do
    getglobal("AutologinAccountButton" .. i):UnlockHighlight();
    if (skip + i > table.getn(Autologin_Table)) then
      getglobal("AutologinAccountButton" .. i):Hide();
    else
      local r = Autologin_Table[skip + i];
      getglobal("AutologinAccountButton" .. i):Show();
      getglobal("AutologinAccountButton" .. i .. "ButtonTextName"):SetText(
          r.name);
      getglobal("AutologinAccountButton" .. i .. "ButtonTextPassword"):SetText(
          'Password: ' .. string.rep("*", string.len(r.password)));

      if (r.character == '-') then
        getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter"):SetText(
            "");
      else
        getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter"):SetText(
            'Character: ' .. r.character);
      end

      if (Autologin_SelectedIdx == skip + i) then
        getglobal("AutologinAccountButton" .. i):LockHighlight();
      end
    end
  end

  if (Autologin_LimitReached) then
    getglobal("AutologinSizeWarning"):Show();
  else
    getglobal("AutologinSizeWarning"):Hide();
  end
end

function Autologin_OnLogin()
  local name = AccountLoginAccountEdit:GetText();
  local password = AccountLoginPasswordEdit:GetText();

  -- Autologin OnLogin
  Autologin_Save(name, password);
  Autologin_OnNameUpdate(name);
  DefaultServerLogin(name, password);
  Autologin_Load();
  Autologin_UpdateUI();
end

function AutologinAccountButton_OnClick() Autologin_SelectAccount(this:GetID()); end

function AutologinAccountButton_OnDoubleClick()
  Autologin_SelectAccount(this:GetID());
  AccountLogin_Login();
end

function Autologin_RemoveAccount()
  if (not Autologin_SelectedIdx) then return end

  table.remove(Autologin_Table, Autologin_SelectedIdx);
  Autologin_Save();
  AccountLoginAccountEdit:SetText("");
  AccountLoginPasswordEdit:SetText("");

  if (Autologin_CurrentPage > 0 and Autologin_CurrentPage * Autologin_PageSize >
      table.getn(Autologin_Table) - 1) then
    Autologin_CurrentPage = Autologin_CurrentPage - 1;
  end

  Autologin_UpdateUI();
end

function Autologin_ClearCharacter()
  if (not Autologin_SelectedIdx) then return end

  Autologin_Table[Autologin_SelectedIdx].character = '-';
  Autologin_Save();
  Autologin_UpdateUI();
end

function Autologin_NextPage()
  if ((Autologin_CurrentPage + 1) * Autologin_PageSize >
      table.getn(Autologin_Table) - 1) then return end
  Autologin_CurrentPage = Autologin_CurrentPage + 1;
  Autologin_UpdateUI();
end

function Autologin_PrevPage()
  if (Autologin_CurrentPage == 0) then return end
  Autologin_CurrentPage = Autologin_CurrentPage - 1;
  Autologin_UpdateUI();
end

-- Vanilla code

FADE_IN_TIME = 2;
DEFAULT_TOOLTIP_COLOR = { 0.8, 0.8, 0.8, 0.09, 0.09, 0.09 };
MAX_PIN_LENGTH = 10;

function AccountLogin_OnLoad()
  this:SetSequence(0);
  this:SetCamera(0);

  TOSFrame.noticeType = "EULA";

  this:RegisterEvent("SHOW_SERVER_ALERT");
  this:RegisterEvent("SHOW_SURVEY_NOTIFICATION");

  local versionType, buildType, version, internalVersion, date = GetBuildInfo();
  AccountLoginVersion:SetText(format(TEXT(VERSION_TEMPLATE), versionType,
                                     version, internalVersion, buildType, date));

  -- Color edit box backdrops
  local backdropColor = DEFAULT_TOOLTIP_COLOR;
  AccountLoginAccountEdit:SetBackdropBorderColor(backdropColor[1],
                                                 backdropColor[2],
                                                 backdropColor[3]);
  AccountLoginAccountEdit:SetBackdropColor(backdropColor[4], backdropColor[5],
                                           backdropColor[6]);
  AccountLoginPasswordEdit:SetBackdropBorderColor(backdropColor[1],
                                                  backdropColor[2],
                                                  backdropColor[3]);
  AccountLoginPasswordEdit:SetBackdropColor(backdropColor[4], backdropColor[5],
                                            backdropColor[6]);
  VirtualKeypadText:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
  VirtualKeypadText:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
end

function AccountLogin_OnShow()
  CurrentGlueMusic = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3";

  -- Try to show the EULA or the TOS
  AccountLogin_ShowUserAgreements();

  local serverName = GetServerName();
  if (serverName) then
    AccountLoginRealmName:SetText(serverName);
  else
    AccountLoginRealmName:Hide()
  end

  -- Autologin OnShow
  Autologin_Load();
  if (table.getn(Autologin_Table) ~= 0) then Autologin_SelectAccount(1); end
  Autologin_UpdateUI();

  if (GetSavedAccountName() == "") then
    AccountLogin_FocusAccountName();
  else
    AccountLogin_FocusPassword();
  end
end

function AccountLogin_FocusPassword() AccountLoginPasswordEdit:SetFocus(); end

function AccountLogin_FocusAccountName() AccountLoginAccountEdit:SetFocus(); end

function AccountLogin_OnChar() end

function AccountLogin_OnKeyDown()
  if (arg1 == "ESCAPE") then
    if (ConnectionHelpFrame:IsVisible()) then
      ConnectionHelpFrame:Hide();
      AccountLoginUI:Show();
    elseif (SurveyNotificationFrame:IsVisible()) then
      -- do nothing
    else
      AccountLogin_Exit();
    end

  elseif (arg1 == "ENTER") then
    if (not TOSAccepted()) then
      return;
    elseif (TOSFrame:IsVisible() or ConnectionHelpFrame:IsVisible()) then
      return;
    elseif (SurveyNotificationFrame:IsVisible()) then
      AccountLogin_SurveyNotificationDone(1);
    end
    AccountLogin_Login();
  elseif (arg1 == "PRINTSCREEN") then
    Screenshot();
  end
end

function AccountLogin_OnEvent(event)
  if (event == "SHOW_SERVER_ALERT") then
    ServerAlertText:SetText(arg1);
    ServerAlertScrollFrame:UpdateScrollChildRect();
    ServerAlertFrame:Show();
  elseif (event == "SHOW_SURVEY_NOTIFICATION") then
    AccountLogin_ShowSurveyNotification();
  end
end

function AccountLogin_Login()
  PlaySound("gsLogin");
  Autologin_OnLogin();
end

function AccountLogin_ManageAccount()
  PlaySound("gsLoginNewAccount");
  LaunchURL(AUTH_NO_TIME_URL);
end

function AccountLogin_LaunchCommunitySite()
  PlaySound("gsLoginNewAccount");
  LaunchURL(COMMUNITY_URL);
end

function AccountLogin_Credits()
  if (not GlueDialog:IsVisible()) then
    PlaySound("gsTitleCredits");
    SetGlueScreen("credits");
  end
end

function AccountLogin_Cinematics()
  if (not GlueDialog:IsVisible()) then
    PlaySound("gsTitleIntroMovie");
    SetGlueScreen("movie");
  end
end

function AccountLogin_Options() PlaySound("gsTitleOptions"); end

function AccountLogin_Exit()
  PlaySound("gsTitleQuit");
  QuitGame();
end

function AccountLogin_ShowSurveyNotification()
  GlueDialog:Hide();
  AccountLoginUI:Hide();
  SurveyNotificationAccept:Enable();
  SurveyNotificationDecline:Enable();
  SurveyNotificationFrame:Show();
end

function AccountLogin_SurveyNotificationDone(accepted)
  SurveyNotificationFrame:Hide();
  SurveyNotificationAccept:Disable();
  SurveyNotificationDecline:Disable();
  SurveyNotificationDone(accepted);
  AccountLoginUI:Show();
end

function AccountLogin_ShowUserAgreements()
  TOSScrollFrame:Hide();
  EULAScrollFrame:Hide();
  ScanningScrollFrame:Hide();
  ContestScrollFrame:Hide();
  TOSText:Hide();
  EULAText:Hide();
  ScanningText:Hide();
  if (not EULAAccepted()) then
    if (ShowEULANotice()) then
      TOSNotice:SetText(EULA_NOTICE);
      TOSNotice:Show();
    end
    AccountLoginUI:Hide();
    TOSFrame.noticeType = "EULA";
    TOSFrameTitle:SetText(EULA_FRAME_TITLE);
    TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth() + 310);
    EULAScrollFrame:Show();
    EULAText:Show();
    TOSFrame:Show();
  elseif (not TOSAccepted()) then
    if (ShowTOSNotice()) then
      TOSNotice:SetText(TOS_NOTICE);
      TOSNotice:Show();
    end
    AccountLoginUI:Hide();
    TOSFrame.noticeType = "TOS";
    TOSFrameTitle:SetText(TOS_FRAME_TITLE);
    TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth() + 310);
    TOSScrollFrame:Show();
    TOSText:Show();
    TOSFrame:Show();
  elseif (not ScanningAccepted() and SHOW_SCANNING_AGREEMENT) then
    if (ShowScanningNotice()) then
      TOSNotice:SetText(SCANNING_NOTICE);
      TOSNotice:Show();
    end
    AccountLoginUI:Hide();
    TOSFrame.noticeType = "SCAN";
    TOSFrameTitle:SetText(SCAN_FRAME_TITLE);
    TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth() + 310);
    ScanningScrollFrame:Show();
    ScanningText:Show();
    TOSFrame:Show();
  elseif (not ContestAccepted() and SHOW_CONTEST_AGREEMENT) then
    if (ShowContestNotice()) then
      TOSNotice:SetText(CONTEST_NOTICE);
      TOSNotice:Show();
    end
    AccountLoginUI:Hide();
    TOSFrame.noticeType = "CONTEST";
    TOSFrameTitle:SetText(CONTEST_FRAME_TITLE);
    TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth() + 310);
    ContestScrollFrame:Show();
    ContestText:Show();
    TOSFrame:Show();
  else
    AccountLoginUI:Show();
    TOSFrame:Hide();
  end
end

-- Virtual keypad functions
local buttonText = {}
function VirtualKeypadFrame_OnEvent(event)
	if ( event == "PLAYER_ENTER_PIN" ) then
		for i=1, 10 do
			buttonText[i] = getglobal("arg"..i)
		end
	end
	-- Randomize location to prevent hacking (yeah right)
	local xPadding = 5;
	local yPadding = 10;
	local xPos = random(xPadding, GlueParent:GetWidth()-VirtualKeypadFrame:GetWidth()-xPadding);
	local yPos = random(yPadding, GlueParent:GetHeight()-VirtualKeypadFrame:GetHeight()-yPadding);
	--VirtualKeypadFrame:SetPoint("TOPLEFT", GlueParent, "TOPLEFT", xPos, -yPos);

	VirtualKeypadFrame:Show();
	VirtualKeypad_UpdateButtons();
end

function VirtualKeypadButton_OnClick()
	local text = VirtualKeypadText:GetText();
	if ( not text ) then
		text = "";
	end
	VirtualKeypadFrame.PIN = VirtualKeypadFrame.PIN..this:GetID();
	VirtualKeypadText:SetText(VirtualKeypadFrame.PIN);
	VirtualKeypad_UpdateButtons();
end

function VirtualKeypadOkayButton_OnClick()
	local PIN = VirtualKeypadText:GetNumber();
	local numNumbers = strlen(PIN);
	if numNumbers < 6 then return end
	local pinNumber = {};
	for i=1, MAX_PIN_LENGTH do
		if ( i <= numNumbers ) then
			pinNumber[i] = nil;
			for j=1, 10 do
				if tonumber(buttonText[j]) == tonumber(strsub(PIN,i,i)) then
					pinNumber[i] = j-1;
				end
			end
		else
			pinNumber[i] = nil;
		end
	end
	PINEntered(pinNumber[1] , pinNumber[2], pinNumber[3], pinNumber[4], pinNumber[5], pinNumber[6], pinNumber[7], pinNumber[8], pinNumber[9], pinNumber[10]);
	VirtualKeypadFrame:Hide();
end

function VirtualKeypad_UpdateButtons()
end
