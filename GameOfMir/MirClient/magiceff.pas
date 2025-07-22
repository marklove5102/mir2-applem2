unit magiceff;

interface

uses
  Windows, SysUtils, HGE, 
  Grobal2, HGETextures, CliUtil, ClFunc, HUtil32, WIl;

const
  MG_READY = 10;
  MG_FLY = 6;
  MG_EXPLOSION = 10;
  READYTIME = 120;
  EXPLOSIONTIME = 100;
  FLYBASE = 10;
  EXPLOSIONBASE = 170;
  //EFFECTFRAME = 260;
  MAXMAGIC = 10;
  FLYOMAAXEBASE = 447;
  THORNBASE = 2967;
  ARCHERBASE = 2607;
  ARCHERBASE2 = 272; //2609;

  FLYFORSEC = 500;
  FIREGUNFRAME = 6;

  MAXEFFECT = 59;//×î´óÐ§¹ûÄ§·¨Ð§¹ûÍ¼Êý
  {
  EffectBase: array[0..MAXEFFECT-1] of integer = (
     0,             //0  È­¿°Àå
     200,           //1  È¸º¹¼ú
     400,           //2  ±Ý°­È­¿°Àå
     600,           //3  ¾Ï¿¬¼ú
     0,             //4  °Ë±¤
     900,           //5  È­¿°Ç³
     920,           //6  È­¿°¹æ»ç
     940,           //7  ·ÚÀÎÀå //½ÃÀüÈ¿°ú¾øÀ½
     20,            //8  °­°Ý,  Magic2
     940,           //9  Æø»ì°è //½ÃÀüÈ¿°ú¾øÀ½
     940,           //10 ´ëÁö¿øÈ£ //½ÃÀüÈ¿°ú¾øÀ½
     940,           //11 ´ëÁö¿øÈ£¸¶ //½ÃÀüÈ¿°ú¾øÀ½
     0,             //12 ¾î°Ë¼ú
     1380,          //13 °á°è
     1500,          //14 ¹é°ñÅõÀÚ¼ÒÈ¯, ¼ÒÈ¯¼ú
     1520,          //15 Àº½Å¼ú
     940,           //16 ´ëÀº½Å
     1560,          //17 Àü±âÃæ°Ý
     1590,          //18 ¼ø°£ÀÌµ¿
     1620,          //19 Áö¿­Àå
     1650,          //20 È­¿°Æø¹ß
     1680,          //21 ´ëÀºÇÏ(Àü±âÆÛÁü)
     0,           //22 ¹Ý¿ù°Ë¹ý
     0,           //23 ¿°È­°á
     0,           //24 ¹«ÅÂº¸
     3960,          //25 Å½±âÆÄ¿¬
     1790,          //26 ´ëÈ¸º¹¼ú
     0,            //27 ½Å¼ö¼ÒÈ¯  Magic2
     3880,          //28 ÁÖ¼úÀÇ¸·
     3920,          //29 »çÀÚÀ±È¸
     3840,          //30 ºù¼³Ç³
     1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
  );
  }
  EffectBase: array[0..MAXEFFECT - 1] of integer = (
    0, {1}
    200, {2}
    400, {3}
    568, {4}
    0, {5}
    900, {6}
    920, {7}
    940, {8}
    20, {9}
    120, {10}
    940, {11}
    940, {12}
    0, {13}
    1380, {14}
    1500, {15}
    1520, {16}
    940, {17}
    1560, {18}
    1590, {19}
    640, {20 1620}
    1650, {21}
    1680, {22}
    0, {23}
    0, {24}
    0, {25}
    3960, {26}
    1790, {27 1790}
    0, {28}
    0, {29}
    3920, {30}
    3840, {31}
    0, {32}
    0{40}, {33}
    130, {34}
    160, {35}
    190, {36}
    0, {37}
    210, {38}
    400, {39}
    600, {40}
    1500, {41}
    650, {42}
    710, {43}
    740, {44}
    910, {45}
    940, {46}
    568{990}, {47}
    1040, {48}
    630, {49}
    0, {50} //±§ÔÂµ¶·¨
    790, {51} //¿ñ·çÕ¶
    840, {52} //ÆÆ¿Õ½£
    810, {53}
    870, {54}
    1110, {55}
    740, {56}
    650, {57}
    360, {58}
    588 {59}
    );
  MAXHITEFFECT = 9 {11};
  {
  HitEffectBase: array[0..MAXHITEFFECT-1] of integer = (
     800,           //0, ¾î°Ë¼ú
     1410,          //1 ¾î°Ë¼ú
     1700,          //2 ¹Ý¿ù°Ë¹ý
     3480,          //3 ¿°È­°á, ½ÃÀÛ
     3390,          //4 ¿°È­°á ¹ÝÂ¦ÀÓ
     1,2,3
  );
  }
  HitEffectBase: array[0..MAXHITEFFECT - 1] of integer = (
    800,{1} //ºÃ¹¥É±
    1410,{2} //´ÌÉ±
    40,
    0,
    3390,
    310,
    660,
    740,
    510
    );
  MAXMAGICTYPE = 16;

type
  TMagicType {Ä§·¨ÀàÐÍ} = (mtReady{×¼±¸}, mtFly{·É} , mtExplosion{±¬·¢},
    mtFlyAxe{·É¸«}, mtFireWind{»ð·ç}, mtFireGun{»ðÅÚ},
    mtLightingThunder{ÕÕÃ÷À×}, mtThunder{À×1}, mtExploBujauk,
    mtBujaukGroundEffect, mtKyulKai, mtFlyArrow,
    mt12, mt13{¹ÖÎïÄ§·¨}, mt14,
    mt15, mt16
    );

  TUseMagicInfo = record
    ServerMagicCode: integer;
    MagicSerial: integer;
    Target: integer; //recogcode
    EffectType: TMagicType;
    EffectNumber: integer;
    TargX: integer;
    TargY: integer;
    Recusion: Boolean;
    AniTime: integer;
//    nFrame: Integer;
  end;
  PTUseMagicInfo = ^TUseMagicInfo;

  TMagicEff = class //Size 0xC8
      m_boActive: Boolean;           //0x04 »î¶¯µÄ
    ServerMagicId: integer; //0x08
    MagicId: Integer;
    MagOwner: TObject; //0x0C
      TargetActor: TObject;      //0x10 Ä¿±ê
    ImgLib: TWMImages; //0x14
    EffectBase: integer; //0x18
    MagExplosionBase: integer; //0x1C
    MagExplosionDir: Boolean;
    px, py: integer; //0x20 0x24
    RX, RY: integer; //0x28 0x2C
    Dir16, OldDir16: byte; //0x30  0x31
    TargetX, TargetY: integer; //0x34 0x38
    TargetRx, TargetRy: integer; //0x3C 0x40
    FlyX, FlyY, OldFlyX, OldFlyY: integer; //0x44 0x48 0x4C 0x50
    FlyXf, FlyYf: Real; //0x54 0x5C
      Repetition: Boolean;       //0x64 //ÖØ¸´
      FixedEffect: Boolean;      //0x65//¹Ì¶¨½á¹û
    NotFixed: Boolean;
    MagicType: integer; //0x68
    NextEffect: TMagicEff; //0x6C
    ExplosionFrame: integer; //0x70
    NextFrameTime: integer; //0x74
    Light: integer; //0x78
    n7C: integer;
    bt80: byte;
    bt81: byte;
      start: integer;        //0x84 //¿ªÊ¼ä¥
    curframe: integer; //0x88
      frame: integer;        //0x8C //ÓÐÐ§Ö¡
    m_nFlyParameter: Integer;
    m_boFlyBlend: Boolean;
    m_boExplosionBlend: Boolean;
  private

    m_dwFrameTime: longword; //0x90
    m_dwStartTime: longword; //0x94
    repeattime: longword; //0x98 ¹Ýº¹ ¾Ö´Ï¸ÞÀÌ¼Ç ½Ã°£ (-1: °è¼Ó)
    steptime: longword; //0x9C
    fireX, fireY: integer; //0xA0 0xA4
    firedisX, firedisY: integer; //0xA8 0xAC
    newfiredisX, newfiredisY: integer; //0xB0 0xB4
    FireMyselfX, FireMyselfY: integer; //0xB8 0xBC
    prevdisx, prevdisy: integer; //0xC0 0xC4
  protected
    procedure GetFlyXY(ms: integer; var fx, fy: integer);
  public
    constructor Create(id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; AniTime: integer);
    destructor Destroy; override;
    function Run: Boolean; dynamic; //false:³¡³µÀ½.
    function Shift: Boolean; dynamic;
    procedure DrawEff(surface: TDirectDrawSurface); dynamic;
  end;

  TDelayMagicEff = class(TMagicEff)
    nDelayTime: LongWord;
    boRun: Boolean;
  public
    constructor Create(id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; AniTime: integer);
    function Run: Boolean; override;
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TFlameIceMagicEff = class(TMagicEff)
  public
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;


  TTigerMagicEff = class(TMagicEff)
    btDir: Byte;
  public
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TFlyingAxe = class(TMagicEff)
    FlyImageBase: integer;
    ReadyFrame: integer;
  public
    constructor Create(id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; AniTime: integer);
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TFlyingBug = class(TMagicEff) //Size 0xD0
    FlyImageBase: integer; //0xC8
    ReadyFrame: integer; //0xCC
  public
    constructor Create(id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType;
      Recusion: Boolean; AniTime: integer);
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TFlyingArrow = class(TFlyingAxe)
  public
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;
  TFlyingFireBall = class(TFlyingAxe) //0xD0
  public
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;
  TCharEffect = class(TMagicEff)
    m_boBlend: Boolean;
  public
    constructor Create(effbase, effframe: integer; Target: TObject; boBlend: Boolean = True);
    function Run: Boolean; override; //false:³¡³µÀ½.
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TMapEffect = class(TMagicEff)
  public
    RepeatCount: integer;
    constructor Create(effbase, effframe: integer; x, y: integer);
    function Run: Boolean; override; //false:³¡³µÀ½.
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TScrollHideEffect = class(TMapEffect)
  public
    constructor Create(effbase, effframe: integer; x, y: integer; Target: TObject);
    function Run: Boolean; override;
  end;

  TLightingEffect = class(TMagicEff)
  public
    constructor Create(effbase, effframe: integer; x, y: integer);
    function Run: Boolean; override;
  end;

  TFireNode = record
    x: integer;
    y: integer;
    firenumber: integer;
  end;

  TFireGunEffect = class(TMagicEff)
  public
    OutofOil: Boolean;
    firetime: longword;
    FireNodes: array[0..FIREGUNFRAME - 1] of TFireNode;
    constructor Create(effbase, sx, sy, tx, ty: integer);
    function Run: Boolean; override;
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TThuderEffect = class(TMagicEff)
  public
    constructor Create(effbase, tx, ty: integer; Target: TObject);
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TLightingThunder = class(TMagicEff)
  public
    constructor Create(effbase, sx, sy, tx, ty: integer; Target: TObject);
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TExploBujaukEffect = class(TMagicEff)
    MagicNumber: integer;
    MagicBlend: Boolean;
  public
    constructor Create(effbase, sx, sy, tx, ty: integer; Target: TObject);
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TBujaukGroundEffect = class(TMagicEff) //Size  0xD0
  public
    MagicNumber: integer; //0xC8
    BoGroundEffect: Boolean; //0xCC
    constructor Create(effbase, magicnumb, sx, sy, tx, ty: integer);
    function Run: Boolean; override;
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;
  TNormalDrawEffect = class(TMagicEff) //Size 0xCC
    boC8: Boolean;
  public
    constructor Create(XX, YY: integer; WmImage: TWMImages; effbase, nX:
      integer; frmTime: longword; boFlag: Boolean);
    function Run: Boolean; override;
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TDelayNormalDrawEffect = class(TNormalDrawEffect)
    dwDelayTick: LongWord;
    boRun: Boolean;
    SoundID: Integer;
  public
    constructor Create(XX, YY: integer; WmImage: TWMImages; effbase, nX:
      integer; frmTime: longword; boFlag: Boolean; nDelayTime: LongWord);
    function Run: Boolean; override;
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;

  TItemLightBeamEffect = class(TMagicEff) // ÎïÆ·¹âÖùÌØÐ§
    m_nLightBeamType: Integer; // ¹âÖùÀàÐÍ
    m_nFrameCount: Integer; // ¶¯»­Ö¡Êý
    m_nFrameTime: Integer; // Ö¡¼ä¸ôÊ±¼ä
    m_dwLastFrameTime: LongWord; // ÉÏ´ÎÖ¡ÇÐ»»Ê±¼ä
    m_nCurrentFrame: Integer; // µ±Ç°Ö¡
    m_boLoop: Boolean; // ÊÇ·ñÑ­»·²¥·Å
  public
    constructor Create(nX, nY: Integer; nLightBeamType, nFrameCount, nFrameTime: Integer);
    function Run: Boolean; override;
    procedure DrawEff(surface: TDirectDrawSurface); override;
  end;
procedure GetEffectBase(mag, mtype: integer; var wimg: TWMImages; var idx: integer);

implementation

uses
  ClMain, Actor, SoundUtil, MShare, WMFile, HGEBase;
{------------------------------------------------------------------------------}
//È¡µÃÄ§·¨Ð§¹ûËùÔÚÍ¼¿â(20071028)
//GetEffectBase(mag, mtype,wimg,idx)
//²ÎÊý£ºmag--¼´¼¼ÄÜÊý¾Ý±íÖÐµÄEffect×Ö¶Î(Ä§·¨Ð§¹û)£¬ÈçÅüÐÇÕ¶´Ë´¦Îª61-1
//      mtype--ÎÞÊµ¼ÊÒâË¼µÄ²ÎÊý£¬´Ë´¦ È¡Öµ
//      wimg--TWMImagesÀà£¬¼´Í¼Æ¬ÏÔÊ¾µÄµØ·½
//      idx---ÔÚ¶ÔÓ¦µÄWILÎÄ¼þ Àï£¬Í¼Æ¬Ëù´¦µÄÎ»ÖÃ
//
//***{EffectBaseÀà£º±£´æ¶ÔÓ¦IDXµÄÖµ¶ÔÓ¦WILÎÄ¼þ Í¼Æ¬µÄÊýÖµ}***  Àý£º idx := EffectBase[mag];
{------------------------------------------------------------------------------}
procedure GetEffectBase(mag, mtype: integer; var wimg: TWMImages; var idx:
  integer);
begin
  wimg := nil;
  idx := 0;
  case mtype of
    0: begin //Ä§·¨Ð§¹û
        case mag of
          27, 34..35, 37..39, 41..42, 43, 44, 45 {46}, 47, 54, 55, 56: begin
              wimg := g_WMagic2Images;
              if mag in [0..MAXEFFECT - 1] then
                idx := EffectBase[mag];
            end;
          8: begin
              if g_WMagic7Images.boInitialize then begin
                wimg := g_WMagic7Images;
                idx := 0;
              end else begin
                wimg := g_WMagic2Images;
                if mag in [0..MAXEFFECT - 1] then
                  idx := EffectBase[mag];
              end;
            end;
          57: begin
              wimg := g_WMagic10Images;
              idx := 360;
            end;
          48: begin
              wimg := g_WMagic6Images;
              idx := 630;
            end;
          33: begin
              wimg := g_WMagic6Images;
              idx := 80;
            end;
          31: begin
              wimg := g_WMons[21];
              if mag in [0..MAXEFFECT - 1] then
                idx := EffectBase[mag];
            end;
          36: begin
              wimg := g_WMons[22];
              if mag in [0..MAXEFFECT - 1] then
                idx := EffectBase[mag];
            end;
          80..82: begin
              wimg := g_WDragonImages;
              if mag = 80 then begin
                if g_Myself.m_nCurrX >= 84 then begin
                  idx := 130;
                end
                else begin
                  idx := 140;
                end;
              end;
              if mag = 81 then begin
                if (g_Myself.m_nCurrX >= 78) and (g_Myself.m_nCurrY >= 48) then
                  begin
                  idx := 150;
                end
                else begin
                  idx := 160;
                end;
              end;
              if mag = 82 then begin
                idx := 180;
              end;
            end;
          89: begin
              wimg := g_WDragonImages;
              idx := 350;
            end;
          (MAGICEX_AMYOUNSUL - 1): begin
              wimg := g_WMagic99Images;
              idx := 588;
            end;
          (MAGICEX_AMYOUNSULGROUP - 1): begin
              wimg := g_WMagic99Images;
              idx := 588;
            end;
          28, 10..11, 3, 19, 46, 50..53: begin
            wimg := g_WMagic99Images;
            idx := EffectBase[mag];
          end;
          9, 58: begin
              wimg := g_WMagic6Images;
              idx := EffectBase[9];
            end;
          49: begin
              wimg := g_WcboEffectImages;
              idx := 3990;
            end;
          69: begin
              wimg := g_WMagic10Images;
              idx := 200;
            end;
          70: begin
              wimg := g_WMagic10Images;
              idx := 60;
            end;
          71: begin
              wimg := g_WMagic10Images;
              idx := 0;
            end;
          113: begin
              wimg := g_WcboEffectImages;
              idx := 1040;
            end;
          114: begin
              wimg := g_WcboEffectImages;
              idx := 640;
            end;
          115: begin
              wimg := g_WcboEffectImages;
              idx := 1280;
            end;
          116: begin
              wimg := g_WcboEffectImages;
              idx := 800;
            end;
          117: begin
              wimg := g_WcboEffectImages;
              idx := 1200;
            end;
          118: begin
              wimg := g_WcboEffectImages;
              idx := 1440;
            end;
          119: begin
              wimg := g_WcboEffectImages;
              idx := 1600;
            end;
          120: begin
              wimg := g_WcboEffectImages;
              idx := 1760;
            end;
          122: begin
              wimg := g_WcboEffectImages;
              idx := 720;
            end;
          123: begin
              wimg := g_WMagic2Images;
              idx := 1370;
            end;
        else begin
            wimg := g_WMagicImages;
            if mag in [0..MAXEFFECT - 1] then
              idx := EffectBase[mag];
          end;
        end;
      end;
    1: begin//¹¥»÷Ð§¹û
        if mag in [0..MAXHITEFFECT - 1] then begin
          idx := HitEffectBase[mag];
        end;
        case mag of
          1: begin
              if g_WMagic7Images.boInitialize then begin
                wimg := g_WMagic7Images;
                idx := 140;
              end else begin
                wimg := g_WMagicImages;
              end;
            end;
          2: begin
              if g_WMagic7Images.boInitialize then begin
                wimg := g_WMagic7Images;
                idx := 310;
              end else begin
                wimg := g_WMagic2Images;
              end;
            end;
          3: wimg := g_WMagic6Images;
          6: wimg := g_WMagic99Images;
          5: wimg := g_WMagic4Images;
          7, 9..15: wimg := g_WMagic2Images;
          8: wimg := g_WMagic6Images;
          16: begin
              wimg := g_WMagic5Images;
              idx := 470;
            end;
          17: begin
              wimg := g_WMagic5Images;
              idx := 630;
            end;
          18: begin
              wimg := g_WMain99Images;
              idx := 1530;
            end
          else
            wimg := g_WMagicImages;
        end;
      end;
    2: begin
      wimg := g_WcboEffectImages;
      case mag of
        0: idx := 160;
        1: idx := 80;
        2: idx := 316;
        3: idx := 560;
        4: idx := 0;
        8: begin
          wimg := g_WMagic6Images;
          idx := 510;
        end;
      end;
    end;
  end;
end;

constructor TMagicEff.Create(id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean;
  AniTime: integer);
var
  tax, tay: integer;
begin
  m_nFlyParameter := 900;
  ImgLib := g_WMagicImages; //±âº»
  NotFixed := False;
  MagExplosionDir := False;
  m_boFlyBlend := True;
  m_boExplosionBlend := True;
  MagicId := 0;

  case mtype of
    mtFly, mtBujaukGroundEffect, mtExploBujauk: begin//ÀïÃæÓÐ»ðÇòÊõ
        start := 0;
        frame := 6;
        curframe := start;
        FixedEffect := False;
        Repetition := Recusion;
        ExplosionFrame := 10;
        if id = 38 then
          frame := 10;
        if id = 39 then begin
          frame := 4;
          ExplosionFrame := 8;
        end;
        if (id - 81 - 3) < 0 then begin
          bt80 := 1;
          Repetition := True;
          if id = 81 then begin
            if g_Myself.m_nCurrX >= 84 then begin
              EffectBase := 130;
            end
            else begin
              EffectBase := 140;
            end;
            bt81 := 1;
          end;
          if id = 82 then begin
            if (g_Myself.m_nCurrX >= 78) and (g_Myself.m_nCurrY >= 48) then begin
              EffectBase := 150;
            end
            else begin
              EffectBase := 160;
            end;
            bt81 := 2;
          end;
          if id = 83 then begin
            EffectBase := 180;
            bt81 := 3;
          end;
          start := 0;
          frame := 10;
          MagExplosionBase := 190;
          ExplosionFrame := 10;
        end;
      end;
    mt12: begin
        start := 0;
        frame := 6;
        curframe := start;
        FixedEffect := False;
        Repetition := Recusion;
        ExplosionFrame := 1;
      end;
    mt13: begin
        start := 0;
        frame := 20;
        curframe := start;
        FixedEffect := True;
        Repetition := False;
        ExplosionFrame := 20;
        ImgLib := g_WMons[21];
      end;
    mtExplosion, mtThunder, mtLightingThunder: begin
        start := 0;
        frame := -1;
        ExplosionFrame := 10;
        curframe := start;
        FixedEffect := True;
        Repetition := False;
        if id = 80 then begin
          bt80 := 2;
          case Random(6) of
            0: begin
                EffectBase := 230;
              end;
            1: begin
                EffectBase := 240;
              end;
            2: begin
                EffectBase := 250;
              end;
            3: begin
                EffectBase := 230;
              end;
            4: begin
                EffectBase := 240;
              end;
            5: begin
                EffectBase := 250;
              end;
          end;
          Light := 4;
          ExplosionFrame := 5;
        end;
        if id = 70 then begin
          bt80 := 3;
          case Random(3) of
            0: begin
                EffectBase := 400;
              end;
            1: begin
                EffectBase := 410;
              end;
            2: begin
                EffectBase := 420;
              end;
          end;
          Light := 4;
          ExplosionFrame := 5;
        end;
        if id = 71 then begin
          bt80 := 3;
          ExplosionFrame := 20;
        end;
        if id = 72 then begin
          bt80 := 3;
          Light := 3;
          ExplosionFrame := 10;
        end;
        if id = 73 then begin
          bt80 := 3;
          Light := 5;
          ExplosionFrame := 20;
        end;
        if id = 74 then begin
          bt80 := 3;
          Light := 4;
          ExplosionFrame := 35;
        end;
        if id = 90 then begin
          EffectBase := 350;
          MagExplosionBase := 350;
          ExplosionFrame := 30;
        end;
      end;
    mt14: begin
        start := 0;
        frame := -1;
        curframe := start;
        FixedEffect := True;
        Repetition := False;
        ImgLib := g_WMagic2Images;
      end;
    mtFlyAxe: begin
        start := 0;
        frame := 3;
        curframe := start;
        FixedEffect := False;
        Repetition := Recusion;
        ExplosionFrame := 3;
      end;
    mtFlyArrow: begin
        start := 0;
        frame := 1;
        curframe := start;
        FixedEffect := False;
        Repetition := Recusion;
        ExplosionFrame := 1;
      end;
    mt15: begin
        start := 0;
        frame := 6;
        curframe := start;
        FixedEffect := False;
        Repetition := Recusion;
        ExplosionFrame := 2;
      end;
    mt16: begin
        start := 0;
        frame := 1;
        curframe := start;
        FixedEffect := False;
        Repetition := Recusion;
        ExplosionFrame := 1;
      end;
  end;
  n7C := 0;
  ServerMagicId := id; //¼­¹öÀÇ ID
  EffectBase := effnum; //MagicDB - Effect
  TargetX := tx; // "   target x
  TargetY := ty; // "   target y

  if bt80 = 1 then begin
    if id = 81 then begin
      dec(sx, 14);
      inc(sy, 20);
    end;
    if id = 81 then begin
      dec(sx, 70);
      dec(sy, 10);
    end;
    if id = 83 then begin
      dec(sx, 60);
      dec(sy, 70);
    end;
    PlaySound(8208);
  end;
  fireX := sx; //
  fireY := sy; //
  FlyX := sx; //
  FlyY := sy;
  OldFlyX := sx;
  OldFlyY := sy;
  FlyXf := sx;
  FlyYf := sy;
  FireMyselfX := g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX;
  FireMyselfY := g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY;
  if bt80 = 0 then begin
    MagExplosionBase := EffectBase + EXPLOSIONBASE;
  end;

  Light := 1;

  if fireX <> TargetX then
    tax := abs(TargetX - fireX)
  else
    tax := 1;
  if fireY <> TargetY then
    tay := abs(TargetY - fireY)
  else
    tay := 1;
  if abs(fireX - TargetX) > abs(fireY - TargetY) then begin
    firedisX := Round((TargetX - fireX) * (500 / tax));
    firedisY := Round((TargetY - fireY) * (500 / tax));
  end
  else begin
    firedisX := Round((TargetX - fireX) * (500 / tay));
    firedisY := Round((TargetY - fireY) * (500 / tay));
  end;

  NextFrameTime := 50;
  m_dwFrameTime := GetTickCount;
  m_dwStartTime := GetTickCount;
  steptime := GetTickCount;
  repeattime := AniTime;
  Dir16 := GetFlyDirection16(sx, sy, tx, ty);
  OldDir16 := Dir16;
  NextEffect := nil;
  m_boActive := True;
  prevdisx := 99999;
  prevdisy := 99999;
end;

destructor TMagicEff.Destroy;
begin
  inherited Destroy;
end;

function TMagicEff.Shift: Boolean;
  function OverThrough(olddir, newdir: integer): Boolean;
  begin
    Result := False;
    if abs(olddir - newdir) >= 2 then begin
      Result := True;
      if ((olddir = 0) and (newdir = 15)) or ((olddir = 15) and (newdir = 0)) then
        Result := False;
    end;
  end;
var
  ms, stepx, stepy: integer;
  tax, tay, shx, shy, passdir16: integer;
  crash: Boolean;//Åö×²
  stepxf, stepyf: Real;
begin
  Result := True;
  if Repetition then begin
    if GetTickCount - steptime > longword(NextFrameTime) then begin
      steptime := GetTickCount;
      inc(curframe);
      if curframe > start + frame - 1 then
        curframe := start;
    end;
  end
  else begin
    if (frame > 0) and (GetTickCount - steptime > longword(NextFrameTime)) then begin
      steptime := GetTickCount;
      inc(curframe);
      if curframe > start + frame - 1 then begin
        curframe := start + frame - 1;
        Result := False;
        exit;
      end;
    end;
  end;

  if (not FixedEffect) then begin//Èç¹ûÎª²»¹Ì¶¨µÄ½á¹û

    crash := False;
    if TargetActor <> nil then begin
      ms := GetTickCount - m_dwFrameTime;
        //ÀÌÀü È¿°ú¸¦ ±×¸°ÈÄ ¾ó¸¶³ª ½Ã°£ÀÌ Èê·¶´ÂÁö?
      m_dwFrameTime := GetTickCount;
      //TargetX, TargetY Àç¼³Á¤
      PlayScene.ScreenXYfromMCXY(TActor(TargetActor).m_nRx,
        TActor(TargetActor).m_nRy,
        TargetX,
        TargetY);
      shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
      shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;
      TargetX := TargetX + shx;
      TargetY := TargetY + shy;

      //»õ·Î¿î Å¸°ÙÀ» ÁÂÇ¥¸¦ »õ·Î ¼³Á¤ÇÑ´Ù.
      if FlyX <> TargetX then
        tax := abs(TargetX - FlyX)
      else
        tax := 1;
      if FlyY <> TargetY then
        tay := abs(TargetY - FlyY)
      else
        tay := 1;
      if abs(FlyX - TargetX) > abs(FlyY - TargetY) then begin
        newfiredisX := Round((TargetX - FlyX) * (500 / tax));
        newfiredisY := Round((TargetY - FlyY) * (500 / tax));
      end
      else begin
        newfiredisX := Round((TargetX - FlyX) * (500 / tay));
        newfiredisY := Round((TargetY - FlyY) * (500 / tay));
      end;

      if firedisX < newfiredisX then
        firedisX := firedisX + _MAX(1, (newfiredisX - firedisX) div 10);
      if firedisX > newfiredisX then
        firedisX := firedisX - _MAX(1, (firedisX - newfiredisX) div 10);
      if firedisY < newfiredisY then
        firedisY := firedisY + _MAX(1, (newfiredisY - firedisY) div 10);
      if firedisY > newfiredisY then
        firedisY := firedisY - _MAX(1, (firedisY - newfiredisY) div 10);

      stepxf := (firedisX / (m_nFlyParameter - 200)) * ms;
      stepyf := (firedisY / (m_nFlyParameter - 200)) * ms;
      FlyXf := FlyXf + stepxf;
      FlyYf := FlyYf + stepyf;
      FlyX := Round(FlyXf);
      FlyY := Round(FlyYf);

      //¹æÇâ Àç¼³Á¤
    //  Dir16 := GetFlyDirection16 (OldFlyX, OldFlyY, FlyX, FlyY);
      OldFlyX := FlyX;
      OldFlyY := FlyY;
      //Åë°ú¿©ºÎ¸¦ È®ÀÎÇÏ±â À§ÇÏ¿©
      passdir16 := GetFlyDirection16(FlyX, FlyY, TargetX, TargetY);

      {DebugOutStr(IntToStr(prevdisx) + ' ' + IntToStr(prevdisy) + ' / ' +
        IntToStr(abs(TargetX - FlyX)) + ' ' + IntToStr(abs(TargetY - FlyY)) + '   '
        +
        IntToStr(firedisX) + '.' + IntToStr(firedisY) + ' ' +
        IntToStr(FlyX) + '.' + IntToStr(FlyY) + ' ' +
        IntToStr(TargetX) + '.' + IntToStr(TargetY));   }
      if ((abs(TargetX - FlyX) <= 15) and (abs(TargetY - FlyY) <= 15)) or
        ((abs(TargetX - FlyX) >= prevdisx) and (abs(TargetY - FlyY) >= prevdisy)) or
        OverThrough(OldDir16, passdir16) then
      begin
        crash := True;
      end
      else begin
        prevdisx := abs(TargetX - FlyX);
        prevdisy := abs(TargetY - FlyY);
        //if (prevdisx <= 5) and (prevdisy <= 5) then crash := TRUE;
      end;
      OldDir16 := passdir16;

    end
    else begin
      ms := GetTickCount - m_dwFrameTime; //È¿°úÀÇ ½ÃÀÛÈÄ ¾ó¸¶³ª ½Ã°£ÀÌ Èê·¶´ÂÁö?

      //      rrx := TargetX - fireX;
      //      rry := TargetY - fireY;

      stepx := Round((firedisX / m_nFlyParameter) * ms);
      stepy := Round((firedisY / m_nFlyParameter) * ms);
      FlyX := fireX + stepx;
      FlyY := fireY + stepy;
    end;

    PlayScene.CXYfromMouseXY(FlyX, FlyY, RX, RY);

    if crash and (TargetActor <> nil) then begin
      FixedEffect := True; //Æø¹ß
      start := 0;
      frame := ExplosionFrame;
      curframe := start;
      Repetition := False;

      //ÅÍÁö´Â »ç¿îµå
      if MagOwner <> nil then
        PlaySound(TActor(MagOwner).m_nMagicExplosionSound);

    end;
    //if not Map.CanFly (Rx, Ry) then
    //   Result := FALSE;
  end;
  if FixedEffect then begin//¹Ì¶¨½á¹û
    if frame = -1 then
      frame := ExplosionFrame;
    if TargetActor = nil then begin
      FlyX := TargetX - ((g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX);
      FlyY := TargetY - ((g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY);
      PlayScene.CXYfromMouseXY(FlyX, FlyY, RX, RY);
    end
    else begin
      RX := TActor(TargetActor).m_nRx;
      RY := TActor(TargetActor).m_nRy;
      PlayScene.ScreenXYfromMCXY(RX, RY, FlyX, FlyY);
      FlyX := FlyX + TActor(TargetActor).m_nShiftX;
      FlyY := FlyY + TActor(TargetActor).m_nShiftY;
    end;
  end;
end;

procedure TMagicEff.GetFlyXY(ms: integer; var fx, fy: integer);
var
  stepx, stepy: integer;
begin
  //  rrx := TargetX - fireX;
  //  rry := TargetY - fireY;

  stepx := Round((firedisX / 900) * ms);
  stepy := Round((firedisY / 900) * ms);
  fx := fireX + stepx;
  fy := fireY + stepy;
end;

function TMagicEff.Run: Boolean;
begin
  Result := Shift;
  if Result then
    if GetTickCount - m_dwStartTime > 10000 then //2000 then
      Result := False
    else
      Result := True;
end;
{------------------------------------------------------------------------------}
//´Ë¹ý³ÌÏÔÊ¾Ä§·¨¼¼ÄÜÆ®ÒÆ¹ý³Ì(20071031)
//DrawEff (surface: TDirectDrawSurface);
//
//***EffectBase£ºÎªEffectBaseÊý×éÀïµÄÊý***
{------------------------------------------------------------------------------}
procedure TMagicEff.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  if m_boActive and ((abs(FlyX - fireX) > 15) or (abs(FlyY - fireY) > 15) or FixedEffect) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      //Óë·½ÏòÓÐ¹ØµÄÄ§·¨Ð§¹û
      if NotFixed then img := EffectBase
      else img := EffectBase + FLYBASE + Dir16 * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        if m_boFlyBlend then DrawBlend(surface, FlyX + px - UNITX div 2 - shx, FlyY + py - UNITY div 2 - shy, d, 1)
        else Surface.Draw(FlyX + px - UNITX div 2 - shx, FlyY + py - UNITY div 2 - shy, d, True);
      end;
    end
    else begin
     //Óë·½ÏòÎÞ¹ØµÄÄ§·¨Ð§¹û£¨ÀýÈç±¬Õ¨£©
      if MagExplosionDir then img := MagExplosionBase + curframe + Dir16 * 10
      else img := MagExplosionBase + curframe; //EXPLOSIONBASE;
      d := ImgLib.GetCachedImage(img, px, py);
      if (MagicId = 66) and (curframe < 20) then begin
        Dec(py, 225);
        Inc(px, 25);
      end;
      if d <> nil then begin
        if m_boExplosionBlend then DrawBlend(surface, FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d, 1)
        else Surface.Draw(FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d, True);
      end;
    end;
  end;
end;

{------------------------------------------------------------}

//      TFlyingAxe : ³¯¾Æ°¡´Â µµ³¢

{------------------------------------------------------------}

constructor TFlyingAxe.Create(id, effnum, sx, sy, tx, ty: integer; mtype:
  TMagicType; Recusion: Boolean; AniTime: integer);
begin
  inherited Create(id, effnum, sx, sy, tx, ty, mtype, Recusion, AniTime);
  FlyImageBase := FLYOMAAXEBASE;
  ReadyFrame := 65;
end;

procedure TFlyingAxe.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  if m_boActive and ((abs(FlyX - fireX) > ReadyFrame) or (abs(FlyY - fireY) >
    ReadyFrame)) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      //
      img := FlyImageBase + Dir16 * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        //¾ËÆÄºí·©µùÇÏÁö ¾ÊÀ½
        surface.Draw(FlyX + px - UNITX div 2 - shx,
          FlyY + py - UNITY div 2 - shy,
          d.ClientRect, d, True);
      end;
    end
    else begin
      {//Á¤Áö, µµ³¢¿¡ ÂïÈù ¸ð½À.
      img := FlyImageBase + Dir16 * 10;
      d := ImgLib.GetCachedImage (img, px, py);
      if d <> nil then begin
         //¾ËÆÄºí·©µùÇÏÁö ¾ÊÀ½
         surface.Draw (FlyX + px - UNITX div 2,
                       FlyY + py - UNITY div 2,
                       d.ClientRect, d, TRUE);
      end;  }
    end;
  end;
end;

{------------------------------------------------------------}

//      TFlyingArrow : ³¯¾Æ°¡´Â È­»ì

{------------------------------------------------------------}

procedure TFlyingArrow.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  //(**6¿ùÆÐÄ¡
  if m_boActive and ((abs(FlyX - fireX) > 40) or (abs(FlyY - fireY) > 40)) then
    begin
    //*)
    (**ÀÌÀü
       if Active then begin //and ((Abs(FlyX-fireX) > 65) or (Abs(FlyY-fireY) > 65)) then begin
    //*)
    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      //³¯¾Æ°¡´Â°Å
      img := FlyImageBase + Dir16; // * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      //(**6¿ùÆÐÄ¡
      if d <> nil then begin
        //¾ËÆÄºí·©µùÇÏÁö ¾ÊÀ½
        surface.Draw(FlyX + px - UNITX div 2 - shx,
          FlyY + py - UNITY div 2 - shy - 46,
          d.ClientRect, d, True);
      end;
      //**)
      (***ÀÌÀü
               if d <> nil then begin
                  //¾ËÆÄºí·©µùÇÏÁö ¾ÊÀ½
                  surface.Draw (FlyX + px - UNITX div 2 - shx,
                                FlyY + py - UNITY div 2 - shy,
                                d.ClientRect, d, TRUE);
               end;
      //**)
    end;
  end;
end;

{--------------------------------------------------------}

constructor TCharEffect.Create(effbase, effframe: integer; Target: TObject; boBlend: Boolean);
begin
  inherited Create(111, effbase,
    TActor(Target).m_nCurrX, TActor(Target).m_nCurrY,
    TActor(Target).m_nCurrX, TActor(Target).m_nCurrY,
    mtExplosion,
    False,
    0);
  TargetActor := Target;
  frame := effframe;
  NextFrameTime := 30;
  m_boBlend := boBlend;

end;

function TCharEffect.Run: Boolean;
begin
  Result := True;
  if GetTickCount - steptime > longword(NextFrameTime) then begin
    steptime := GetTickCount;
    inc(curframe);
    if curframe > start + frame - 1 then begin
      curframe := start + frame - 1;
      Result := False;
    end;
  end;
end;

procedure TCharEffect.DrawEff(surface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  if TargetActor <> nil then begin
    RX := TActor(TargetActor).m_nRx;
    RY := TActor(TargetActor).m_nRy;
    PlayScene.ScreenXYfromMCXY(RX, RY, FlyX, FlyY);
    FlyX := FlyX + TActor(TargetActor).m_nShiftX;
    FlyY := FlyY + TActor(TargetActor).m_nShiftY;
    d := ImgLib.GetCachedImage(EffectBase + curframe, px, py);
    if d <> nil then begin
      if m_boBlend then DrawBlend(surface, FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d, 1)
      else surface.Draw(FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d.ClientRect, d, fxBlend);
    end;
  end;
end;

{--------------------------------------------------------}

constructor TMapEffect.Create(effbase, effframe: integer; x, y: integer);
begin
  inherited Create(111, effbase, x, y, x, y, mtExplosion, False, 0);
  TargetActor := nil;
  frame := effframe;
  NextFrameTime := 30;
  RepeatCount := 0;
end;

function TMapEffect.Run: Boolean;
begin
  Result := True;
  if GetTickCount - steptime > longword(NextFrameTime) then begin
    steptime := GetTickCount;
    inc(curframe);
    if curframe > start + frame - 1 then begin
      curframe := start + frame - 1;
      if RepeatCount > 0 then begin
        dec(RepeatCount);
        curframe := start;
      end
      else
        Result := False;
    end;
  end;
end;

procedure TMapEffect.DrawEff(surface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  RX := TargetX;
  RY := TargetY;
  PlayScene.ScreenXYfromMCXY(RX, RY, FlyX, FlyY);
  d := ImgLib.GetCachedImage(EffectBase + curframe, px, py);
  if d <> nil then begin
    DrawBlend(surface,
      FlyX + px - UNITX div 2,
      FlyY + py - UNITY div 2,
      d, 1);
  end;
end;

{--------------------------------------------------------}

constructor TScrollHideEffect.Create(effbase, effframe: integer; x, y: integer; Target: TObject);
begin
  inherited Create(effbase, effframe, x, y);
  //TargetCret := TActor(target);//ÔÚ³öÏÖÓÐÈËÓÃËæ»úÖ®ÀàÊ±£¬½«ÉèÖÃÄ¿±ê
end;

function TScrollHideEffect.Run: Boolean;
begin
  Result := inherited Run;
  if frame = 7 then
    if g_TargetCret <> nil then
      PlayScene.DeleteActor(g_TargetCret.m_nRecogId);
end;

{--------------------------------------------------------}

constructor TLightingEffect.Create(effbase, effframe: integer; x, y: integer);
begin

end;

function TLightingEffect.Run: Boolean;
begin
  Result := False; //Jacky
end;

{--------------------------------------------------------}

constructor TFireGunEffect.Create(effbase, sx, sy, tx, ty: integer);
begin
  inherited Create(111, effbase,
    sx, sy,
    tx, ty, //TActor(target).XX, TActor(target).m_nCurrY,
    mtFireGun,
    True,
    0);
  NextFrameTime := 50;
  SafeFillChar(FireNodes, sizeof(TFireNode) * FIREGUNFRAME, #0);
  OutofOil := False;
  firetime := GetTickCount;
end;

function TFireGunEffect.Run: Boolean;
var
  i: integer;
  allgone: Boolean;
begin
  Result := True;
  if GetTickCount - steptime > longword(NextFrameTime) then begin
    Shift;
    steptime := GetTickCount;
    //if not FixedEffect then begin  //¸ñÇ¥¿¡ ¸ÂÁö ¾Ê¾ÒÀ¸¸é
    if (not OutofOil) and (MagOwner <> nil) then begin
      if (abs(RX - TActor(MagOwner).m_nRx) >= 5) or (abs(RY -
        TActor(MagOwner).m_nRy) >= 5) or (GetTickCount - firetime > 800) then
        OutofOil := True;
      for i := FIREGUNFRAME - 2 downto 0 do begin
        FireNodes[i].firenumber := FireNodes[i].firenumber + 1;
        FireNodes[i + 1] := FireNodes[i];
      end;
      FireNodes[0].firenumber := 1;
      FireNodes[0].x := FlyX;
      FireNodes[0].y := FlyY;
    end
    else begin
      allgone := True;
      for i := FIREGUNFRAME - 2 downto 0 do begin
        if FireNodes[i].firenumber <= FIREGUNFRAME then begin
          FireNodes[i].firenumber := FireNodes[i].firenumber + 1;
          FireNodes[i + 1] := FireNodes[i];
          allgone := False;
        end;
      end;
      if allgone then
        Result := False;
    end;
  end;
end;

procedure TFireGunEffect.DrawEff(surface: TDirectDrawSurface);
var
  i, {num, } shx, shy, fireX, fireY, prx, pry, img: integer;
  d: TDirectDrawSurface;
begin
  prx := -1;
  pry := -1;
  for i := 0 to FIREGUNFRAME - 1 do begin
    if (FireNodes[i].firenumber <= FIREGUNFRAME) and (FireNodes[i].firenumber >
      0) then begin
      shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
      shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

      img := EffectBase + (FireNodes[i].firenumber - 1);
      d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        fireX := FireNodes[i].x + px - UNITX div 2 - shx;
        fireY := FireNodes[i].y + py - UNITY div 2 - shy;
        if (fireX <> prx) or (fireY <> pry) then begin
          prx := fireX;
          pry := fireY;
          DrawBlend(surface, fireX, fireY, d, 1);
        end;
      end;
    end;
  end;
end;

{--------------------------------------------------------}

constructor TThuderEffect.Create(effbase, tx, ty: integer; Target: TObject);
begin
  inherited Create(111, effbase,
    tx, ty,
    tx, ty, //TActor(target).XX, TActor(target).m_nCurrY,
    mtThunder,
    False,
    0);
  TargetActor := Target;

end;

procedure TThuderEffect.DrawEff(surface: TDirectDrawSurface);
var
  img, px, py: integer;
  d: TDirectDrawSurface;
begin
  img := EffectBase;
  d := ImgLib.GetCachedImage(img + curframe, px, py);
  if d <> nil then begin
    DrawBlend(surface,
      FlyX + px - UNITX div 2,
      FlyY + py - UNITY div 2,
      d, 1);
  end;
end;

{--------------------------------------------------------}

constructor TLightingThunder.Create(effbase, sx, sy, tx, ty: integer; Target: TObject);
begin
  inherited Create(111, effbase,
    sx, sy,
    tx, ty, //TActor(target).XX, TActor(target).m_nCurrY,
    mtLightingThunder,
    False,
    0);
  TargetActor := Target;
  //ImgLib := g_WMagic99Images;
end;

procedure TLightingThunder.DrawEff(surface: TDirectDrawSurface);
var
  img, sx, sy, px, py: integer;
  d: TDirectDrawSurface;
begin
  img := EffectBase + Dir16 * 10;
  if curframe < 6 then begin

        //sx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
        //sy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    d := ImgLib.GetCachedImage(img + curframe, px, py);
    if (d <> nil) and (MagOwner <> nil) then begin
      PlayScene.ScreenXYfromMCXY(TActor(MagOwner).m_nRx,
        TActor(MagOwner).m_nRy,
        sx,
        sy); 
      DrawBlend(surface,
        sx + px - UNITX div 2,
        sy + py - UNITY div 2,
        d, 1);
    end;
  end;
  {if (curframe < 10) and (TargetActor <> nil) then begin
     d := ImgLib.GetCachedImage (EffectBase + 17*10 + curframe, px, py);
     if d <> nil then begin
        PlayScene.ScreenXYfromMCXY (TActor(TargetActor).RX,
                                    TActor(TargetActor).RY,
                                    sx,
                                    sy);
        DrawBlend (surface,
                   sx + px - UNITX div 2,
                   sy + py - UNITY div 2,
                   d, 1);
     end;
  end;}
end;

{--------------------------------------------------------}

constructor TExploBujaukEffect.Create(effbase, sx, sy, tx, ty: integer; Target:
  TObject);
begin
  inherited Create(111, effbase,
    sx, sy,
    tx, ty,
    mtExploBujauk,
    True,
    0);
  frame := 8;
  TargetActor := Target;
  NextFrameTime := 50;
  MagicNumber := 0;
  MagicBlend := False;
end;

procedure TExploBujaukEffect.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
  //  meff: TMapEffect;
begin
  if m_boActive and ((abs(FlyX - fireX) > 30) or (abs(FlyY - fireY) > 30) or FixedEffect) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      img := EffectBase + Dir16 * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        if MagicBlend then
          DrawBlend(surface,
            FlyX + px - UNITX div 2 - shx,
            FlyY + py - UNITY div 2 - shy,
            d, 1)
        else
          surface.Draw(FlyX + px - UNITX div 2 - shx,
            FlyY + py - UNITY div 2 - shy,
            d.ClientRect, d, True);
      end;
    end
    else begin
      img := MagExplosionBase + curframe;
      if MagicNumber = 17 then d := g_WMagicImages.GetCachedImage(img, px, py)
      else d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2,
          FlyY + py - UNITY div 2,
          d, 1);
      end;
    end;
  end;
end;

{--------------------------------------------------------}

constructor TBujaukGroundEffect.Create(effbase, magicnumb, sx, sy, tx, ty:
  integer);
begin
  inherited Create(111, effbase,
    sx, sy,
    tx, ty,
    mtBujaukGroundEffect,
    True,
    0);
  frame := 3;
  MagicNumber := magicnumb;
  BoGroundEffect := False;
  NextFrameTime := 50;
  //ImgLib := g_WMagic99Images;
end;

function TBujaukGroundEffect.Run: Boolean;
begin
  Result := inherited Run;
  if not FixedEffect then begin
    if ((abs(TargetX - FlyX) <= 15) and (abs(TargetY - FlyY) <= 15)) or
      ((abs(TargetX - FlyX) >= prevdisx) and (abs(TargetY - FlyY) >= prevdisy))
        then begin
      FixedEffect := True;  //¹Ì¶¨½á¹û
      start := 0;
      frame := ExplosionFrame;
      curframe := start;
      Repetition := False;
      //ÅÍÁö´Â »ç¿îµå
      if MagOwner <> nil then
        PlaySound(TActor(MagOwner).m_nMagicExplosionSound);

      Result := True;
    end
    else begin
      prevdisx := abs(TargetX - FlyX);
      prevdisy := abs(TargetY - FlyY);
    end;
  end;
end;

procedure TBujaukGroundEffect.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
  //  meff: TMapEffect;
begin
  if m_boActive and ((abs(FlyX - fireX) > 30) or (abs(FlyY - fireY) > 30) or
    FixedEffect) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      //³¯¾Æ°¡´Â°Å
      img := EffectBase + Dir16 * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        surface.Draw(FlyX + px - UNITX div 2 - shx,
          FlyY + py - UNITY div 2 - shy,
          d.ClientRect, d, True);   
      end;
    end
    else begin
      //Æø¹ß
      if MagicNumber = 11 then begin
        img := 534 + curframe;
        ImgLib := g_WMagic99Images;
      end else
      if MagicNumber = 12 then begin
        img := 510 + curframe;
        ImgLib := g_WMagic99Images;
      end else
      if MagicNumber = 46 then begin
        GetEffectBase(MagicNumber - 1, 0, ImgLib, img);
        img := img + 10 + curframe;
        ImgLib := g_WMagic2Images;
      end;
      d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2, // - shx,
          FlyY + py - UNITY div 2, // - shy,
          d, 1);
      end;
      {if not BoGroundEffect and (curframe = 8) then begin
         BoGroundEffect := TRUE;
         meff := TMapEffect.Create (img+2, 6, TargetRx, TargetRy);
         meff.NextFrameTime := 100;
         //meff.RepeatCount := 1;
         PlayScene.GroundEffectList.Add (meff);
      end; }
    end;
  end;
end;

{ TNormalDrawEffect }

constructor TNormalDrawEffect.Create(XX, YY: integer; WmImage: TWMImages;
  effbase, nX: integer; frmTime: longword; boFlag: Boolean);
begin
  inherited Create(111, effbase, XX, YY, XX, YY, mtReady, True, 0);
  ImgLib := WmImage;
  EffectBase := effbase;
  start := 0;
  curframe := 0;
  frame := nX;
  NextFrameTime := frmTime;
  boC8 := boFlag;
end;

procedure TNormalDrawEffect.DrawEff(surface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  nRx, nRy, nPx, nPy: integer;
begin
  d := ImgLib.GetCachedImage(EffectBase + curframe, nPx, nPy);
  if d <> nil then begin
    if MagOwner <> nil then PlayScene.ScreenXYfromMCXY(TActor(MagOwner).m_nRX, TActor(MagOwner).m_nRY, nRx, nRy)
    else PlayScene.ScreenXYfromMCXY(FlyX, FlyY, nRx, nRy);
    if boC8 then begin
      DrawBlend(surface, nRx + nPx - UNITX div 2, nRy + nPy - UNITY div 2, d, 1);
    end
    else begin
      surface.Draw(nRx + nPx - UNITX div 2, nRy + nPy - UNITY div 2, d.ClientRect, d, True);
    end;
  end;
end;

function TNormalDrawEffect.Run: Boolean;
begin
  Result := True;
  if m_boActive and (GetTickCount - steptime > longword(NextFrameTime)) then
    begin
    steptime := GetTickCount;
    inc(curframe);
    if curframe > start + frame - 1 then begin
      curframe := start;
      Result := False;
    end;
  end;
end;

{ TFlyingBug }

constructor TFlyingBug.Create(id, effnum, sx, sy, tx, ty: integer;
  mtype: TMagicType; Recusion: Boolean; AniTime: integer);
begin
  inherited Create(id, effnum, sx, sy, tx, ty, mtype, Recusion, AniTime);
  FlyImageBase := FLYOMAAXEBASE;
  ReadyFrame := 65;
end;

procedure TFlyingBug.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  if m_boActive and ((abs(FlyX - fireX) > ReadyFrame) or (abs(FlyY - fireY) >
    ReadyFrame)) then begin
    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      img := FlyImageBase + (Dir16 div 2) * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        surface.Draw(FlyX + px - UNITX div 2 - shx,
          FlyY + py - UNITY div 2 - shy,
          d.ClientRect, d, True);
      end;
    end
    else begin
      img := curframe + MagExplosionBase;
      d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        surface.Draw(FlyX + px - UNITX div 2,
          FlyY + py - UNITY div 2,
          d.ClientRect, d, True);
      end;
    end;
  end;
end;

{ TFlyingFireBall }

procedure TFlyingFireBall.DrawEff(surface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  if m_boActive and ((abs(FlyX - fireX) > ReadyFrame) or (abs(FlyY - fireY) >
    ReadyFrame)) then begin
    d := ImgLib.GetCachedImage(FlyImageBase + (GetFlyDirection(FlyX, FlyY,
      TargetX, TargetY) * 10) + curframe, px, py);
    if d <> nil then
      DrawBlend(surface,
        FlyX + px - UNITX div 2,
        FlyY + py - UNITY div 2,
        d, 1);
  end;
end;

{ TDelayNormalDrawEffect }

constructor TDelayNormalDrawEffect.Create(XX, YY: integer; WmImage: TWMImages; effbase, nX: integer; frmTime: longword;
  boFlag: Boolean; nDelayTime: LongWord);
begin
  inherited Create(xx, yy, WmImage, effbase, nx, frmTime, boFlag);
  dwDelayTick := GetTickCount + nDelayTime;
  boRun := False;
  SoundID := -1;
end;

procedure TDelayNormalDrawEffect.DrawEff(surface: TDirectDrawSurface);
begin
  if boRun then
    inherited;
end;

function TDelayNormalDrawEffect.Run: Boolean;
begin
  Result := True;
  if boRun then begin
    Result := inherited Run;
  end else begin
    if GetTickCount > dwDelayTick then begin
      //10522
      if SoundID > 0 then
        PlaySound(SoundID); //Damian
      boRun := True;
    end;
  end;
end;

{ TTigerMagicEff }

procedure TTigerMagicEff.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  if m_boActive and ((abs(FlyX - fireX) > 15) or (abs(FlyY - fireY) > 15) or FixedEffect) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      //³¯¾Æ°¡´Â°Å
      img := EffectBase + btDir * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        surface.Draw(FlyX + px - UNITX div 2 - shx, FlyY + py - UNITY div 2 - shy, d.ClientRect, d, True);
      end;
      d := ImgLib.GetCachedImage(img + curframe + 80, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2 - shx,
          FlyY + py - UNITY div 2 - shy,
          d, 1);
      end;
    end
    else begin
      //ÅÍÁö´Â°Å
      img := MagExplosionBase + curframe + btDir * 10;
      d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        surface.Draw(FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d.ClientRect, d, True);
      end;
      d := ImgLib.GetCachedImage(img + 80, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2,
          FlyY + py - UNITY div 2,
          d, 1);
      end;
      d := ImgLib.GetCachedImage(img + 160, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2,
          FlyY + py - UNITY div 2,
          d, 1);
      end;
    end;
  end;
end;

{ TDelayMagicEff }

constructor TDelayMagicEff.Create(id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean;
  AniTime: integer);
begin
  inherited;
  boRun := False;
end;

procedure TDelayMagicEff.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  if not boRun then exit;
  if m_boActive and ((abs(FlyX - fireX) > 15) or (abs(FlyY - fireY) > 15) or FixedEffect) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      img := EffectBase + Dir16 * 10;
      d := ImgLib.GetCachedImage(img + curframe + 160, px, py);
      if d <> nil then begin
        surface.Draw(FlyX + px - UNITX div 2 - shx, FlyY + py - UNITY div 2 - shy, d.ClientRect, d, True);
      end;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2 - shx,
          FlyY + py - UNITY div 2 - shy,
          d, 1);
      end;
    end
    else begin
      img := MagExplosionBase + curframe; //EXPLOSIONBASE;
      d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        DrawBlend(surface,
          FlyX + px - UNITX div 2,
          FlyY + py - UNITY div 2,
          d, 1);
      end;
    end;
  end;
end;

function TDelayMagicEff.Run: Boolean;
begin
  Result := True;
  if (not boRun) then begin
    if GetTickCount > nDelayTime then begin
      boRun := True;
      m_dwFrameTime := GetTickCount;
      m_dwStartTime := GetTickCount;
      steptime := GetTickCount;
      Result := inherited Run;
    end;
  end else
    Result := inherited Run;
end;

{ TFlameIceMagicEff }

procedure TFlameIceMagicEff.DrawEff(surface: TDirectDrawSurface);
var
  img: integer;
  d: TDirectDrawSurface;
  shx, shy: integer;
begin
  if m_boActive and ((abs(FlyX - fireX) > 15) or (abs(FlyY - fireY) > 15) or FixedEffect) then begin

    shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
    shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;

    if not FixedEffect then begin
      //³¯¾Æ°¡´Â°Å
      img := EffectBase + FLYBASE + Dir16 * 10;
      d := ImgLib.GetCachedImage(img + curframe, px, py);
      if d <> nil then begin
        DrawBlend(surface, FlyX + px - UNITX div 2 - shx, FlyY + py - UNITY div 2 - shy, d, 1);
      end;

      img := 400 + FLYBASE + Dir16 * 10;
      d := g_WMagic2Images.GetCachedImage(img + (curframe mod 4), px, py);
      if d <> nil then begin
        DrawBlend(surface, FlyX + px - UNITX div 2 - shx, FlyY + py - UNITY div 2 - shy, d, 1);
      end;
    end
    else begin
      //ÅÍÁö´Â°Å
      img := MagExplosionBase + curframe; //EXPLOSIONBASE;
      d := ImgLib.GetCachedImage(img, px, py);
      if d <> nil then begin
        DrawBlend(surface, FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d, 1)
      end;

      img := 570 + curframe; //EXPLOSIONBASE;
      d := g_WMagic2Images.GetCachedImage(img, px, py);
      if d <> nil then begin
        DrawBlend(surface, FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d, 1)
      end;
    end;
  end;
end;

end;

{ TItemLightBeamEffect }

constructor TItemLightBeamEffect.Create(nX, nY: Integer; nLightBeamType, nFrameCount, nFrameTime: Integer);
begin
  inherited Create(0, 0, nX, nY, nX, nY, 0, mtReady, False, 0);
  m_nLightBeamType := nLightBeamType;
  m_nFrameCount := nFrameCount;
  m_nFrameTime := nFrameTime;
  m_dwLastFrameTime := GetTickCount;
  m_nCurrentFrame := 0;
  m_boLoop := True; // ¹âÖùÐ§¹ûÑ­»·²¥·Å
  m_boActive := True;
  NextFrameTime := nFrameTime;
  frame := nFrameCount;
  start := 0;
  curframe := 0;
end;

function TItemLightBeamEffect.Run: Boolean;
begin
  Result := True;
  if not m_boActive then begin
    Result := False;
    Exit;
  end;
  
  // ¼ì²éÊÇ·ñÐèÒªÇÐ»»Ö¡
  if GetTickCount - m_dwLastFrameTime >= m_nFrameTime then begin
    m_dwLastFrameTime := GetTickCount;
    Inc(m_nCurrentFrame);
    
    // Èç¹û²¥·ÅÍêËùÓÐÖ¡£¬ÖØÐÂ¿ªÊ¼Ñ­»·
    if m_nCurrentFrame >= m_nFrameCount then begin
      if m_boLoop then begin
        m_nCurrentFrame := 0;
      end else begin
        m_boActive := False;
        Result := False;
        Exit;
      end;
    end;
    
    curframe := m_nCurrentFrame;
  end;
end;

procedure TItemLightBeamEffect.DrawEff(surface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  px, py: Integer;
  shx, shy: Integer;
begin
  if not m_boActive then Exit;
  
  // ¼ÆËãÆÁÄ»Æ«ÒÆ
  shx := (g_Myself.m_nRx * UNITX + g_Myself.m_nShiftX) - FireMyselfX;
  shy := (g_Myself.m_nRy * UNITY + g_Myself.m_nShiftY) - FireMyselfY;
  
  // ¸ù¾Ý¹âÖùÀàÐÍÑ¡ÔñÍ¼Æ¬¿â
  case m_nLightBeamType of
    1: begin // ½ðÉ«¹âÖù
        d := g_WMagic2Images.GetCachedImage(1000 + m_nCurrentFrame, px, py);
      end;
    2: begin // À¶É«¹âÖù
        d := g_WMagic2Images.GetCachedImage(1100 + m_nCurrentFrame, px, py);
      end;
    3: begin // ºìÉ«¹âÖù
        d := g_WMagic2Images.GetCachedImage(1200 + m_nCurrentFrame, px, py);
      end;
    4: begin // ÂÌÉ«¹âÖù
        d := g_WMagic2Images.GetCachedImage(1300 + m_nCurrentFrame, px, py);
      end;
    5: begin // ×ÏÉ«¹âÖù
        d := g_WMagic2Images.GetCachedImage(1400 + m_nCurrentFrame, px, py);
      end;
    else begin // Ä¬ÈÏ°×É«¹âÖù
        d := g_WMagic2Images.GetCachedImage(900 + m_nCurrentFrame, px, py);
      end;
  end;
  
  if d <> nil then begin
    // »æÖÆ¹âÖùÐ§¹û£¬Î»ÖÃÔÚÎïÆ·ÏÂ·½
    DrawBlend(surface,
      TargetX + px - UNITX div 2 - shx,
      TargetY + py - UNITY div 2 - shy + 20, // ÏòÏÂÆ«ÒÆ20ÏñËØ
      d, 1);
  end;
end;

end.