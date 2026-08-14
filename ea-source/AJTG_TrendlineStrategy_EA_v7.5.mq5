//+------------------------------------------------------------------+
//|  AJTG Trendline Strategy EA v7.5                                 |
//|  Average Joe Trading Group  •  Est. 2025                         |
//|                                                                   |
//|  FULL REDESIGN OF ENTRY FLOWS IN v7.5:                          |
//|                                                                   |
//|  ── CONTINUATION (CONT) ────────────────────────────────────────|
//|  Step 3 : Price rejects trendline. AL drawn:                    |
//|           Uptrend   : HH  → 3rd touch LOW                       |
//|           Downtrend : LL  → 3rd touch HIGH                      |
//|  Confirm : First candle that CLOSES through AL in trend dir.    |
//|           (up for BUY, down for SELL) → yellow confirm box      |
//|  EZ      : Next candle closing in same direction → green EZ box |
//|  Agg     : Bar after EZ — RSI in window → ENTER                 |
//|  Cons    : Price pushes away from EZ, then RETESTS and REJECTS  |
//|           EZ in same direction — RSI in window → ENTER          |
//|                                                                   |
//|  ── BREAKOUT (BREAK) ───────────────────────────────────────────|
//|  Step 3 : Price closes THROUGH trendline. AL drawn:             |
//|           Uptrend break (SELL): HH → 3rd touch HIGH (breaks up) |
//|           Dntrend break (BUY) : LL → 3rd touch LOW  (breaks dn) |
//|  Confirm : The 3rd touch / break candle IS the confirmation.    |
//|           → red step-3 box already drawn. Wait for next candle  |
//|           closing in breakout direction → go to EZ              |
//|  EZ      : Next candle closing in breakout direction → green EZ |
//|  Agg     : Bar after EZ — RSI in window → ENTER                 |
//|  Cons    : Price pushes away from EZ, then RETESTS and REJECTS  |
//|           EZ in breakout direction — RSI in window → ENTER      |
//|                                                                   |
//|  OTHER CHANGES:                                                  |
//|  · Conservative mode re-added (InpAggressive toggle)            |
//|  · ST_WAIT_EZ added between confirmation and EZ states          |
//|  · DrawConfirmBox() draws yellow box on AL-break confirm candle  |
//|  · All v7.4 retained: labels, AL datetime anchors, TP ladder    |
//+------------------------------------------------------------------+
#property copyright "Average Joe Trading Group"
#property version   "7.50"
#property strict
#include <Trade\Trade.mqh>

//==========================================================================
//  ENUMS
//==========================================================================
enum EAJTG_State
{
   ST_SCAN,
   ST_TL,           // waiting for 3rd touch
   ST_WAIT_CONFIRM, // CONT: waiting for AL break confirm candle
                    // BREAK: waiting for next candle in breakout dir
   ST_WAIT_EZ,      // waiting for EZ candle (2nd candle in entry dir)
   ST_EZ,           // EZ drawn, waiting for entry trigger
   ST_CONS_PUSH,    // conservative: waiting for price to push away
   ST_CONS_RETEST,  // conservative: waiting for retest + RSI
   ST_IN_TRADE,
   ST_COOLDOWN
};
enum EAJTG_Dir   { DIR_NONE, DIR_BUY, DIR_SELL };
enum EAJTG_Setup { SETUP_NONE, SETUP_CONT, SETUP_BREAK };

//==========================================================================
//  INPUTS
//==========================================================================
input group "=== LOT SIZE ==="
input double InpLot          = 0.1;

input group "=== SL/TP FOREX (pips) ==="
input double InpSLFx         = 10;
input double InpTP1Fx        = 10;
input double InpTP2Fx        = 20;
input double InpTP3Fx        = 30;

input group "=== SL/TP GOLD (pips) ==="
input double InpSLGold       = 150;
input double InpTP1Gold      = 100;
input double InpTP2Gold      = 200;
input double InpTP3Gold      = 300;

input group "=== TRAILING ==="
input double InpTrailPips    = 5;
input double InpTrailGapFx   = 10;
input double InpTrailGapGold = 100;

input group "=== ENTRY MODE ==="
input bool   InpAggressive   = true;   // true=aggressive  false=conservative
input int    InpConsPips     = 10;     // pips away from EZ before retest counts

input group "=== SWING DETECTION ==="
input int    InpSwingLen     = 5;
input int    InpScanBars     = 150;

input group "=== RSI ==="
input int    InpRsiPeriod    = 14;
input double InpRsiBuyMin    = 50.0;
input double InpRsiBuyMax    = 55.0;
input double InpRsiSelMin    = 45.0;
input double InpRsiSelMax    = 50.0;
input double InpRsiExitBuy   = 70.0;
input double InpRsiExitSell  = 30.0;

input group "=== VISUALS ==="
input bool   InpDraw         = true;
input color  InpColTLUp      = clrDodgerBlue;
input color  InpColTLDn      = clrRed;
input color  InpColSwLow     = clrAqua;
input color  InpColSwHigh    = clrOrange;
input color  InpColS3        = clrRed;
input color  InpColAL        = clrOrange;
input color  InpColConfirm   = clrYellow;
input color  InpColEZ        = clrLime;
input color  InpColAgg       = clrYellow;
input color  InpColCons      = clrWhite;

//==========================================================================
//  GLOBALS
//==========================================================================
EAJTG_State g_st    = ST_SCAN;
EAJTG_Dir   g_dir   = DIR_NONE;
EAJTG_Setup g_setup = SETUP_NONE;
bool        g_isUp  = false;

int    g_tl_bar1 = 0, g_tl_bar2 = 0;
double g_tl_p1   = 0, g_tl_p2   = 0;
int    g_bars_elapsed = 0;

double   g_between_extreme = 0;
int      g_between_bar     = 0;

int    g_touch3_bar = 0;
double g_touch3_h   = 0, g_touch3_l = 0;

// Action line
double   g_al_p1 = 0, g_al_p2 = 0;
int      g_al_b1 = 0, g_al_b2 = 0;
datetime g_al_t1 = 0, g_al_t2 = 0;

// Entry zone
bool   g_ezDone  = false;
double g_ezH     = 0, g_ezL = 0;

// Conservative push tracking
bool   g_pushed  = false;

ulong    g_ticket    = 0;
int      g_lastBars  = 0;
int      g_cooldown  = 0;
int      g_rsiHnd    = INVALID_HANDLE;
datetime g_lastPrint = 0;
int      g_objId     = 0;

#define BTN_NEWSETUP  "AJTG_BTN_NEWSETUP"
#define MP_BG         "AJTG_MP_BG"
#define MP_TITLE      "AJTG_MP_TITLE"
#define MP_SL_L       "AJTG_MP_SL_L"
#define MP_TP1_L      "AJTG_MP_TP1_L"
#define MP_TP2_L      "AJTG_MP_TP2_L"
#define MP_TP3_L      "AJTG_MP_TP3_L"
#define MP_SL_E       "AJTG_MP_SL_E"
#define MP_TP1_E      "AJTG_MP_TP1_E"
#define MP_TP2_E      "AJTG_MP_TP2_E"
#define MP_TP3_E      "AJTG_MP_TP3_E"
#define MP_BTN        "AJTG_MP_BTN"
#define MP_MIN        "AJTG_MP_MIN"
#define MP_STATE      "AJTG_MP_Minimized"
#define MP_GSEP       "AJTG_MP_GSEP"
#define MP_GTIT       "AJTG_MP_GTIT"
#define MP_GSL_L      "AJTG_MP_GSL_L"
#define MP_GTP1_L     "AJTG_MP_GTP1_L"
#define MP_GTP2_L     "AJTG_MP_GTP2_L"
#define MP_GTP3_L     "AJTG_MP_GTP3_L"
#define MP_GSL_E      "AJTG_MP_GSL_E"
#define MP_GTP1_E     "AJTG_MP_GTP1_E"
#define MP_GTP2_E     "AJTG_MP_GTP2_E"
#define MP_GTP3_E     "AJTG_MP_GTP3_E"

//==========================================================================
//  INIT / DEINIT
//==========================================================================
int OnInit()
{
   g_rsiHnd = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
   if(g_rsiHnd == INVALID_HANDLE){ Alert("AJTG: RSI handle failed"); return INIT_FAILED; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      Print("⚠️  Algo Trading is OFF — enable it in the MT5 toolbar");
   Print("✅ AJTG EA v7.5 | ",_Symbol," | ",EnumToString(_Period),
         " | Mode: ",(InpAggressive?"AGGRESSIVE":"CONSERVATIVE"));
   FullReset(false);
   CreatePanel();
   PopulatePanel();
   CreateNewSetupButton();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_rsiHnd != INVALID_HANDLE) IndicatorRelease(g_rsiHnd);
   Comment("");
   RemoveTimer();
   RemovePanel();
}

//==========================================================================
//  ONTICK
//==========================================================================
void OnTick()
{
   RunTradeManager();

   int  bars   = Bars(_Symbol, _Period);
   bool newBar = (bars != g_lastBars);
   if(newBar) g_lastBars = bars;

   if(g_st == ST_IN_TRADE)
   {
      if(newBar) CheckRSIExit();
      UpdateTimer(); UpdateTPLabels();
      return;
   }
   if(!newBar){ UpdateTimer(); UpdateTPLabels(); return; }

   if(g_st == ST_COOLDOWN){ if(--g_cooldown <= 0) FullReset(true); UpdateTimer(); return; }

   if(g_st != ST_SCAN) g_bars_elapsed++;

   double rsi = GetRSI(1);

   switch(g_st)
   {
      case ST_SCAN:         DoScan();            break;
      case ST_TL:           DoThirdTouch();      break;
      case ST_WAIT_CONFIRM: DoWaitConfirm();     break;
      case ST_WAIT_EZ:      DoWaitEZ();          break;
      case ST_EZ:           DoEZ(rsi);           break;
      case ST_CONS_PUSH:    DoPush();            break;
      case ST_CONS_RETEST:  DoRetest(rsi);       break;
   }
   UpdateTimer();
   UpdateTPLabels();
}

void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(t.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(t.deal)) return;
   long ent=HistoryDealGetInteger(t.deal,DEAL_ENTRY);
   if(ent==DEAL_ENTRY_IN)
   {
      Sleep(300);
      ulong pos=HistoryDealGetInteger(t.deal,DEAL_POSITION_ID);
      if(PositionSelectByTicket(pos)) SetupTracking(pos);
   }
   else if(ent==DEAL_ENTRY_OUT||ent==DEAL_ENTRY_OUT_BY)
   {
      ulong pos=HistoryDealGetInteger(t.deal,DEAL_POSITION_ID);
      if(!PositionSelectByTicket(pos))
      {
         CleanupTrade(pos);
         if(pos==g_ticket){ g_ticket=0; g_st=ST_COOLDOWN; g_cooldown=5; }
      }
   }
}

void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
{
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(sp==MP_BTN)  ApplyPanel();
      if(sp==MP_MIN){ SetMini(!IsMini()); UpdatePanelVis(); ObjectSetInteger(0,MP_MIN,OBJPROP_STATE,false); }
      if(sp==BTN_NEWSETUP)
      {
         Print("AJTG: 🔄 NEW SETUP requested");
         FullReset(true);
         ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_STATE,false);
         ChartRedraw(0);
      }
   }
}

//==========================================================================
//  SWING HELPERS
//==========================================================================
bool IsSwingLow(int bar,int wing)
{
   double lo=iLow(_Symbol,_Period,bar); if(lo<=0) return false;
   for(int k=1;k<=wing;k++)
      if(iLow(_Symbol,_Period,bar+k)<=lo||iLow(_Symbol,_Period,bar-k)<=lo) return false;
   return true;
}
bool IsSwingHigh(int bar,int wing)
{
   double hi=iHigh(_Symbol,_Period,bar); if(hi<=0) return false;
   for(int k=1;k<=wing;k++)
      if(iHigh(_Symbol,_Period,bar+k)>=hi||iHigh(_Symbol,_Period,bar-k)>=hi) return false;
   return true;
}

//==========================================================================
//  STEP 1+2: SCAN — 3-POINT SEQUENTIAL STRUCTURE
//==========================================================================
void DoScan()
{
   int wing=InpSwingLen;
   int maxBar=MathMin(InpScanBars,Bars(_Symbol,_Period)-wing-2);

   //── UPTREND : HL1 → HH → HL2 ────────────────────────────────────────
   for(int i=wing+1;i<=maxBar;i++)
   {
      if(!IsSwingLow(i,wing)) continue;
      double hl2=iLow(_Symbol,_Period,i);
      for(int j=i+wing+1;j<=maxBar;j++)
      {
         if(!IsSwingHigh(j,wing)) continue;
         double hh_j=iHigh(_Symbol,_Period,j);
         for(int k=j+wing+1;k<=maxBar;k++)
         {
            if(!IsSwingLow(k,wing)) continue;
            double hl1=iLow(_Symbol,_Period,k);
            if(hl1>=hl2) continue;
            double peakH=hh_j; int peakB=j;
            for(int m=i+1;m<k;m++)
               if(iHigh(_Symbol,_Period,m)>peakH){ peakH=iHigh(_Symbol,_Period,m); peakB=m; }
            g_tl_bar1=k; g_tl_p1=hl1; g_tl_bar2=i; g_tl_p2=hl2;
            g_between_extreme=peakH; g_between_bar=peakB;
            g_isUp=true; g_bars_elapsed=0; g_st=ST_TL;
            if(InpDraw)
            {
               DrawSwingBox("AJTG_SL1",    k,     hl1,   InpColSwLow,  "HL1");
               DrawSwingBox("AJTG_SH_MID", peakB, peakH, InpColSwHigh, "HH");
               DrawSwingBox("AJTG_SL2",    i,     hl2,   InpColSwLow,  "HL2");
               DrawTrendline();
            }
            Print("AJTG: ▲ UP | HL1=",DoubleToString(hl1,_Digits),"@",k,
                  " HH=",DoubleToString(peakH,_Digits),"@",peakB,
                  " HL2=",DoubleToString(hl2,_Digits),"@",i);
            return;
         }
      }
   }

   //── DOWNTREND : LH1 → LL → LH2 ──────────────────────────────────────
   for(int i=wing+1;i<=maxBar;i++)
   {
      if(!IsSwingHigh(i,wing)) continue;
      double lh2=iHigh(_Symbol,_Period,i);
      for(int j=i+wing+1;j<=maxBar;j++)
      {
         if(!IsSwingLow(j,wing)) continue;
         double ll_j=iLow(_Symbol,_Period,j);
         for(int k=j+wing+1;k<=maxBar;k++)
         {
            if(!IsSwingHigh(k,wing)) continue;
            double lh1=iHigh(_Symbol,_Period,k);
            if(lh1<=lh2) continue;
            double troughL=ll_j; int troughB=j;
            for(int m=i+1;m<k;m++)
               if(iLow(_Symbol,_Period,m)<troughL){ troughL=iLow(_Symbol,_Period,m); troughB=m; }
            g_tl_bar1=k; g_tl_p1=lh1; g_tl_bar2=i; g_tl_p2=lh2;
            g_between_extreme=troughL; g_between_bar=troughB;
            g_isUp=false; g_bars_elapsed=0; g_st=ST_TL;
            if(InpDraw)
            {
               DrawSwingBox("AJTG_SH1",    k,       lh1,    InpColSwHigh, "LH1");
               DrawSwingBox("AJTG_SL_MID", troughB, troughL,InpColSwLow,  "LL");
               DrawSwingBox("AJTG_SH2",    i,       lh2,    InpColSwHigh, "LH2");
               DrawTrendline();
            }
            Print("AJTG: ▼ DN | LH1=",DoubleToString(lh1,_Digits),"@",k,
                  " LL=",DoubleToString(troughL,_Digits),"@",troughB,
                  " LH2=",DoubleToString(lh2,_Digits),"@",i);
            return;
         }
      }
   }
}

//==========================================================================
//  PRICE PROJECTIONS
//==========================================================================
double TLPrice(int bar)
{
   int b1=g_tl_bar1+g_bars_elapsed, b2=g_tl_bar2+g_bars_elapsed;
   if(b1==b2) return g_tl_p1;
   return g_tl_p2+(g_tl_p2-g_tl_p1)/(double)(b1-b2)*(double)(b2-bar);
}

double ALPrice(int bar)
{
   if(g_al_t1==0||g_al_t2==0||g_al_t1==g_al_t2) return 0;
   datetime tBar=iTime(_Symbol,_Period,bar); if(tBar==0) return 0;
   return g_al_p1+(g_al_p2-g_al_p1)/(double)(g_al_t2-g_al_t1)*(double)(tBar-g_al_t1);
}

//==========================================================================
//  STEP 3: 3RD TOUCH  ── draws action line for BOTH setups
//
//  CONTINUATION (wick touch, close stays same side of TL):
//    · Red step-3 box drawn on this candle
//    · Action line: Uptrend   BUY  → HH → 3rd-touch LOW
//                   Downtrend SELL → LL → 3rd-touch HIGH
//    · State → ST_WAIT_CONFIRM (wait for AL break candle)
//
//  BREAKOUT (close crosses TL):
//    · Red step-3 box drawn on this candle (this IS the confirm candle)
//    · Action line: Uptrend   BREAK(SELL) → HH → 3rd-touch HIGH
//                   Downtrend BREAK(BUY)  → LL → 3rd-touch LOW
//    · State → ST_WAIT_EZ  (next candle in breakout dir = EZ candle)
//==========================================================================
void DoThirdTouch()
{
   double pip=OnePip(), tlNow=TLPrice(1);
   double c1=iClose(_Symbol,_Period,1), l1=iLow(_Symbol,_Period,1), h1=iHigh(_Symbol,_Period,1);
   bool touch=false, isCont=false;

   if(g_isUp)
   {
      // Uptrend: wick must touch or breach TL from above
      if(l1<=tlNow+pip*3){ touch=true; isCont=(c1>tlNow-pip*2); }
   }
   else
   {
      // Downtrend: wick must touch or breach TL from below
      if(h1>=tlNow-pip*3){ touch=true; isCont=(c1<tlNow+pip*2); }
   }
   if(!touch) return;

   g_touch3_h=h1; g_touch3_l=l1;
   // CONT: trade in direction of trend. BREAK: trade against trend.
   g_dir  =g_isUp?(isCont?DIR_BUY:DIR_SELL):(isCont?DIR_SELL:DIR_BUY);
   g_setup=isCont?SETUP_CONT:SETUP_BREAK;

   if(InpDraw){ DrawStep3Box(h1,l1); DrawStep3Label(h1,l1,isCont); }

   // ── Find the 2nd extreme between HL2/LH2 and the 3rd touch candle ──
   // This is the peak (uptrend) or trough (downtrend) that formed AFTER
   // the second TL anchor point and BEFORE the 3rd touch.
   // It is the visible origin of the action line on the chart.
   //
   // Search range: from bar 2 (one bar before 3rd touch) back to
   //               (g_tl_bar2 + g_bars_elapsed + 1) which is just past HL2/LH2.
   int hl2_bar_aged = g_tl_bar2 + g_bars_elapsed;  // bar index of HL2/LH2 now
   int al_b1   = 2;       // default to bar 2 if no clear extreme found
   double al_p1 = g_isUp ? h1 : l1;  // fallback price

   if(g_isUp)
   {
      // Uptrend: find highest high between HL2 and 3rd touch → "HH2"
      double peakH = -DBL_MAX; int peakB = 2;
      for(int m = 2; m <= hl2_bar_aged; m++)
      {
         double hi = iHigh(_Symbol,_Period,m);
         if(hi > peakH){ peakH = hi; peakB = m; }
      }
      al_b1 = peakB; al_p1 = peakH;
      if(InpDraw) DrawSwingBox("AJTG_SH_HH2", peakB, peakH, InpColSwHigh, "HH2");
      Print("AJTG: HH2=",DoubleToString(peakH,_Digits),"@bar",peakB," (AL anchor)");
   }
   else
   {
      // Downtrend: find lowest low between LH2 and 3rd touch → "LL2"
      double troughL = DBL_MAX; int troughB = 2;
      for(int m = 2; m <= hl2_bar_aged; m++)
      {
         double lo = iLow(_Symbol,_Period,m);
         if(lo < troughL){ troughL = lo; troughB = m; }
      }
      al_b1 = troughB; al_p1 = troughL;
      if(InpDraw) DrawSwingBox("AJTG_SL_LL2", troughB, troughL, InpColSwLow, "LL2");
      Print("AJTG: LL2=",DoubleToString(troughL,_Digits),"@bar",troughB," (AL anchor)");
   }

   if(isCont)
   {
      //── CONTINUATION action line ─────────────────────────────────────
      // Uptrend  BUY : HH2 (peak after HL2) → 3rd touch LOW
      // Downtrend SELL: LL2 (trough after LH2) → 3rd touch HIGH
      g_al_b1=al_b1; g_al_p1=al_p1;
      if(g_isUp){ g_al_b2=1; g_al_p2=l1; }
      else      { g_al_b2=1; g_al_p2=h1; }
      if(InpDraw) DrawActionLine();
      g_ezDone=false; g_pushed=false;
      g_st=ST_WAIT_CONFIRM;
      Print("AJTG: CONT ",EnumToString(g_dir)," | AL: ",DoubleToString(al_p1,_Digits),
            " → ",DoubleToString(g_al_p2,_Digits)," | waiting confirm");
   }
   else
   {
      //── BREAKOUT action line ─────────────────────────────────────────
      // Uptrend   BREAK (SELL): HH2 → 3rd touch HIGH (price broke above)
      // Downtrend BREAK (BUY) : LL2 → 3rd touch LOW  (price broke below)
      g_al_b1=al_b1; g_al_p1=al_p1;
      if(g_isUp){ g_al_b2=1; g_al_p2=h1; }
      else      { g_al_b2=1; g_al_p2=l1; }
      if(InpDraw) DrawActionLine();
      g_ezDone=false; g_pushed=false;
      g_st=ST_WAIT_EZ;
      Print("AJTG: BREAK ",EnumToString(g_dir)," | AL: ",DoubleToString(al_p1,_Digits),
            " → ",DoubleToString(g_al_p2,_Digits)," | confirm=this candle | waiting EZ");
   }
}

//==========================================================================
//  ST_WAIT_CONFIRM  (CONT only)
//  Wait for first candle that CLOSES through the action line
//  in the direction of the trade.
//    BUY  setup: close ABOVE AL → confirmation
//    SELL setup: close BELOW AL → confirmation
//  Draw a yellow confirm box on that candle, then move to ST_WAIT_EZ.
//==========================================================================
void DoWaitConfirm()
{
   double alNow=ALPrice(1);
   if(alNow==0){ Throttle("AJTG: ALPrice=0 — check AL datetimes"); return; }
   double c1=iClose(_Symbol,_Period,1);
   bool confirmed=(g_dir==DIR_BUY)?(c1>alNow):(c1<alNow);
   if(confirmed)
   {
      if(InpDraw) DrawConfirmBox(iHigh(_Symbol,_Period,1), iLow(_Symbol,_Period,1));
      g_st=ST_WAIT_EZ;
      Print("AJTG: ✔ CONT confirm | close=",DoubleToString(c1,_Digits),
            " AL=",DoubleToString(alNow,_Digits)," | waiting for EZ candle");
   }
   else
      Throttle("AJTG: Waiting confirm | close="+DoubleToString(c1,_Digits)
               +" AL="+DoubleToString(alNow,_Digits));
}

//==========================================================================
//  ST_WAIT_EZ
//  Wait for the next candle that closes in the trade direction.
//  That candle becomes the Entry Zone.
//    BUY  setup: candle must close higher than it opened (bullish close)
//    SELL setup: candle must close lower than it opened (bearish close)
//  Draw the EZ box on that candle, then move to ST_EZ.
//==========================================================================
void DoWaitEZ()
{
   double o1=iOpen (_Symbol,_Period,1);
   double c1=iClose(_Symbol,_Period,1);
   double h1=iHigh (_Symbol,_Period,1);
   double l1=iLow  (_Symbol,_Period,1);

   bool ezCandle=(g_dir==DIR_BUY)?(c1>o1):(c1<o1);
   if(ezCandle)
   {
      g_ezH=h1; g_ezL=l1; g_ezDone=true;
      if(InpDraw) DrawEZBox();
      g_pushed=false;
      g_st=ST_EZ;
      Print("AJTG: 📦 EZ H=",DoubleToString(g_ezH,_Digits)," L=",DoubleToString(g_ezL,_Digits));
   }
   else
      Throttle("AJTG: Waiting EZ candle in direction "+EnumToString(g_dir));
}

//==========================================================================
//  ST_EZ: Entry Zone drawn — look for entry trigger
//
//  AGGRESSIVE: On every bar after EZ, if RSI is in window → enter.
//  CONSERVATIVE: Switch to push-away phase first.
//==========================================================================
void DoEZ(double rsi)
{
   if(!g_ezDone) return;

   if(InpAggressive)
   {
      if(RSI_OK(rsi))
      {
         if(InpDraw) DrawEntryLabel(1, false);
         OpenTrade();
      }
      else Throttle("AJTG: Agg waiting RSI="+DoubleToString(rsi,1)+" need "+RSI_Need());
   }
   else
   {
      g_st=ST_CONS_PUSH;
   }
}

//==========================================================================
//  CONSERVATIVE — Phase 1: price must push AWAY from EZ by InpConsPips
//==========================================================================
void DoPush()
{
   double pip=OnePip(), c1=iClose(_Symbol,_Period,1);
   bool pushed=(g_dir==DIR_BUY  && c1>g_ezH+InpConsPips*pip) ||
               (g_dir==DIR_SELL && c1<g_ezL-InpConsPips*pip);
   if(pushed)
   {
      g_pushed=true;
      g_st=ST_CONS_RETEST;
      Print("AJTG: Cons — pushed away, waiting for EZ retest");
   }
}

//==========================================================================
//  CONSERVATIVE — Phase 2: price must RETURN to EZ and reject it,
//  then RSI must confirm.
//
//  Retest condition:
//    BUY : low wicks into or below EZ top, but candle CLOSES above EZ bottom
//    SELL: high wicks into or above EZ bottom, but candle CLOSES below EZ top
//==========================================================================
void DoRetest(double rsi)
{
   double pip=OnePip();
   double l1=iLow(_Symbol,_Period,1), h1=iHigh(_Symbol,_Period,1), c1=iClose(_Symbol,_Period,1);

   bool retested=(g_dir==DIR_BUY  && l1<=g_ezH+pip*2 && c1>=g_ezL-pip) ||
                 (g_dir==DIR_SELL && h1>=g_ezL-pip*2  && c1<=g_ezH+pip);
   if(retested)
   {
      if(RSI_OK(rsi))
      {
         if(InpDraw) DrawEntryLabel(1, true);
         OpenTrade();
      }
      else Throttle("AJTG: Cons retest RSI not ready ("+DoubleToString(rsi,1)+") need "+RSI_Need());
   }
}

//==========================================================================
//  RSI GATE
//==========================================================================
bool RSI_OK(double rsi)
{
   if(g_dir==DIR_BUY)  return (rsi>=InpRsiBuyMin && rsi<=InpRsiBuyMax);
   else                return (rsi>=InpRsiSelMin && rsi<=InpRsiSelMax);
}
string RSI_Need()
{
   if(g_dir==DIR_BUY) return DoubleToString(InpRsiBuyMin,1)+"-"+DoubleToString(InpRsiBuyMax,1);
   return DoubleToString(InpRsiSelMin,1)+"-"+DoubleToString(InpRsiSelMax,1);
}

//==========================================================================
//  OPEN TRADE
//==========================================================================
void OpenTrade()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { Print("AJTG: ⚠️  Algo trading disabled"); return; }

   double pip=OnePip(); bool isGld=IsGold(_Symbol);
   double sl_p  =isGld?GVget("AJTG_OVR_GD_SL", InpSLGold) :GVget("AJTG_OVR_FX_SL", InpSLFx);
   double tp1_p =isGld?GVget("AJTG_OVR_GD_TP1",InpTP1Gold):GVget("AJTG_OVR_FX_TP1",InpTP1Fx);
   double tp2_p =isGld?GVget("AJTG_OVR_GD_TP2",InpTP2Gold):GVget("AJTG_OVR_FX_TP2",InpTP2Fx);
   double tp3_p =isGld?GVget("AJTG_OVR_GD_TP3",InpTP3Gold):GVget("AJTG_OVR_FX_TP3",InpTP3Fx);
   bool   isBuy=(g_dir==DIR_BUY);
   int    digs=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   int    ff=(int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   ENUM_ORDER_TYPE_FILLING fill;
   if((ff&(int)SYMBOL_FILLING_IOC)!=0)      fill=ORDER_FILLING_IOC;
   else if((ff&(int)SYMBOL_FILLING_FOK)!=0) fill=ORDER_FILLING_FOK;
   else                                      fill=ORDER_FILLING_RETURN;

   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.volume=InpLot;
   req.deviation=30; req.magic=20250001; req.type_filling=fill;
   req.comment="AJTG_"+EnumToString(g_setup)+"_"+EnumToString(g_dir);

   if(isBuy)
   {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      req.type=ORDER_TYPE_BUY; req.price=ask;
      req.sl=NormalizeDouble(ask-sl_p*pip,digs);
      req.tp=NormalizeDouble(ask+tp3_p*pip,digs);
   }
   else
   {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      req.type=ORDER_TYPE_SELL; req.price=bid;
      req.sl=NormalizeDouble(bid+sl_p*pip,digs);
      req.tp=NormalizeDouble(bid-tp3_p*pip,digs);
   }

   if(OrderSend(req,res))
   {
      g_ticket=res.order; g_st=ST_IN_TRADE;
      Print("AJTG: ✔ TRADE #",g_ticket," ",EnumToString(g_dir)," ",EnumToString(g_setup),
            " Lot=",InpLot," SL=",DoubleToString(req.sl,digs)," TP=",DoubleToString(req.tp,digs));
      Alert("AJTG ✔ ",EnumToString(g_dir)," ",EnumToString(g_setup)," #",g_ticket);
   }
   else
      Print("AJTG: ✖ OrderSend | Err=",GetLastError()," Ret=",res.retcode);
}

//==========================================================================
//  RSI EXIT
//==========================================================================
void CheckRSIExit()
{
   if(g_ticket==0||!PositionSelectByTicket(g_ticket)) return;
   double rsi=GetRSI(1);
   ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   bool ex=(pt==POSITION_TYPE_BUY&&rsi>=InpRsiExitBuy)||(pt==POSITION_TYPE_SELL&&rsi<=InpRsiExitSell);
   if(ex)
   {
      string sym=PositionGetString(POSITION_SYMBOL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(PartialClose(g_ticket,sym,vol,pt==POSITION_TYPE_BUY))
         Print("AJTG: ✔ RSI EXIT | RSI=",DoubleToString(rsi,1));
   }
}

//==========================================================================
//  TRADE MANAGER
//==========================================================================
void RunTradeManager()
{
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)) continue;
      string id=IntegerToString(tk); if(!GlobalVariableCheck("AJTG_T1_"+id)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      double tp1=GlobalVariableGet("AJTG_T1_"+id),
             tp2=GlobalVariableGet("AJTG_T2_"+id),
             tp3=GlobalVariableGet("AJTG_T3_"+id);
      bool isB=GlobalVariableGet("AJTG_BD_"+id)==1.0;
      bool h1v=GlobalVariableGet("AJTG_H1_"+id)==1.0,
           h2v=GlobalVariableGet("AJTG_H2_"+id)==1.0,
           h3v=GlobalVariableGet("AJTG_H3_"+id)==1.0,
           h3p=GlobalVariableGet("AJTG_H3P_"+id)==1.0;
      double bid=SymbolInfoDouble(sym,SYMBOL_BID),
             pip=GetPipSize(sym),
             entry=PositionGetDouble(POSITION_PRICE_OPEN),
             lots=PositionGetDouble(POSITION_VOLUME);
      int digs=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);

      if(GlobalVariableCheck("AJTG_INEW_"+id))
      {
         double tr=GlobalVariableGet("AJTG_INEW_"+id);
         if(tr>0)
         {
            if(ModSLTP(tk,sym,GlobalVariableGet("AJTG_ISL_"+id),GlobalVariableGet("AJTG_ITP_"+id)))
            { GlobalVariableDel("AJTG_INEW_"+id); GlobalVariableDel("AJTG_ISL_"+id); GlobalVariableDel("AJTG_ITP_"+id); }
            else GlobalVariableSet("AJTG_INEW_"+id,tr-1.0);
         }
      }
      if(GlobalVariableCheck("AJTG_PSL_"+id))
      {
         double psl=GlobalVariableGet("AJTG_PSL_"+id),
                pt=GlobalVariableCheck("AJTG_PSLT_"+id)?GlobalVariableGet("AJTG_PSLT_"+id):10.0;
         if(psl>0&&pt>0)
         {
            if(ModSL(tk,sym,psl)){ UpdateSLLine(tk,psl); GlobalVariableDel("AJTG_PSL_"+id); GlobalVariableDel("AJTG_PSLT_"+id); }
            else GlobalVariableSet("AJTG_PSLT_"+id,pt-1.0);
         }
      }
      if(!h1v&&(isB?bid>=tp1:bid<=tp1))
      {
         double cv=CalcVol(sym,lots,25.0);
         if(cv>0&&PartialClose(tk,sym,cv,isB))
         { GlobalVariableSet("AJTG_H1_"+id,1.0); GlobalVariableSet("AJTG_PSL_"+id,entry); lots=NormalizeDouble(lots-cv,2); Alert("🎯 TP1 | ",sym); }
      }
      if(!h2v&&(isB?bid>=tp2:bid<=tp2))
      {
         if(PositionSelectByTicket(tk)) lots=PositionGetDouble(POSITION_VOLUME);
         double cv=CalcVol(sym,lots,33.3);
         if(cv>0&&PartialClose(tk,sym,cv,isB))
         { GlobalVariableSet("AJTG_H2_"+id,1.0); GlobalVariableSet("AJTG_PSL_"+id,tp1); lots=NormalizeDouble(lots-cv,2); Alert("🎯 TP2 | ",sym); }
      }
      if(!h3v&&(isB?bid>=tp3:bid<=tp3))
      {
         if(PositionSelectByTicket(tk)) lots=PositionGetDouble(POSITION_VOLUME);
         double cv=CalcVol(sym,lots,50.0);
         if(cv>0&&PartialClose(tk,sym,cv,isB))
         { GlobalVariableSet("AJTG_H3_"+id,1.0); GlobalVariableSet("AJTG_PSL_"+id,tp2); lots=NormalizeDouble(lots-cv,2); Alert("🎯 TP3 | ",sym," — runner open"); }
      }
      if(h1v&&!h3v)
      {
         double gap=IsGold(sym)?InpTrailGapGold:InpTrailGapFx, base=h2v?tp2:tp1;
         if(isB?bid>=base+pip:bid<=base-pip)
         {
            double nsl=isB?NormalizeDouble(bid-gap*pip,digs):NormalizeDouble(bid+gap*pip,digs);
            if(isB&&nsl<entry) nsl=entry; if(!isB&&nsl>entry) nsl=entry;
            double pv=GlobalVariableCheck("AJTG_PSL_"+id)?GlobalVariableGet("AJTG_PSL_"+id):0,
                   cs=PositionGetDouble(POSITION_SL),
                   bs=isB?MathMax(cs,pv):(pv>0?MathMin(cs,pv):cs);
            if(isB?nsl>bs:nsl<bs) GlobalVariableSet("AJTG_PSL_"+id,nsl);
         }
      }
      if(h3v&&!h3p)
      {
         double tr=isB?tp3+InpTrailPips*pip:tp3-InpTrailPips*pip;
         if(isB?bid>=tr:bid<=tr){ GlobalVariableSet("AJTG_H3P_"+id,1.0); GlobalVariableSet("AJTG_PSL_"+id,tp3); }
      }
   }
}

void SetupTracking(ulong tk)
{
   if(!PositionSelectByTicket(tk)) return;
   string sym=PositionGetString(POSITION_SYMBOL);
   double ent=PositionGetDouble(POSITION_PRICE_OPEN);
   bool isB=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   int digs=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   bool isGd=IsGold(sym); double pip=GetPipSize(sym);
   double sl =isGd?GVget("AJTG_OVR_GD_SL", InpSLGold) :GVget("AJTG_OVR_FX_SL", InpSLFx);
   double tp1=isGd?GVget("AJTG_OVR_GD_TP1",InpTP1Gold):GVget("AJTG_OVR_FX_TP1",InpTP1Fx);
   double tp2=isGd?GVget("AJTG_OVR_GD_TP2",InpTP2Gold):GVget("AJTG_OVR_FX_TP2",InpTP2Fx);
   double tp3=isGd?GVget("AJTG_OVR_GD_TP3",InpTP3Gold):GVget("AJTG_OVR_FX_TP3",InpTP3Fx);
   double slP=isB?ent-sl*pip:ent+sl*pip;
   double tp1P=isB?ent+tp1*pip:ent-tp1*pip;
   double tp2P=isB?ent+tp2*pip:ent-tp2*pip;
   double tp3P=isB?ent+tp3*pip:ent-tp3*pip;
   string id=IntegerToString(tk);
   GlobalVariableSet("AJTG_SL_"+id,slP);  GlobalVariableSet("AJTG_T1_"+id,tp1P);
   GlobalVariableSet("AJTG_T2_"+id,tp2P); GlobalVariableSet("AJTG_T3_"+id,tp3P);
   GlobalVariableSet("AJTG_BD_"+id,isB?1.0:0.0);
   GlobalVariableSet("AJTG_H1_"+id,0.0);  GlobalVariableSet("AJTG_H2_"+id,0.0);
   GlobalVariableSet("AJTG_H3_"+id,0.0);  GlobalVariableSet("AJTG_H3P_"+id,0.0);
   GlobalVariableSet("AJTG_IL_"+id,InpLot);
   GlobalVariableSet("AJTG_INEW_"+id,10.0);
   GlobalVariableSet("AJTG_ISL_"+id,slP); GlobalVariableSet("AJTG_ITP_"+id,tp3P);
   PlotLevels(tk,slP,tp1P,tp2P,tp3P);
   Print("📊 #",tk," ",sym," E=",DoubleToString(ent,digs),
         " SL=",DoubleToString(slP,digs),
         " TP1/2/3=",DoubleToString(tp1P,digs),"/",DoubleToString(tp2P,digs),"/",DoubleToString(tp3P,digs));
}

void CleanupTrade(ulong tk)
{
   string id=IntegerToString(tk);
   string keys[]={"SL","T1","T2","T3","BD","H1","H2","H3","H3P","PSL","PSLT","IL","INEW","ISL","ITP"};
   for(int i=0;i<15;i++) GlobalVariableDel("AJTG_"+keys[i]+"_"+id);
   RemoveLevels(tk);
}

//==========================================================================
//  VISUALS
//==========================================================================
void DrawSwingBox(string nm,int bar,double price,color clr,string label="")
{
   ObjectDelete(0,nm); ObjectDelete(0,nm+"_LBL");
   double pip=OnePip(); int wing=InpSwingLen, bars=Bars(_Symbol,_Period);
   int bL=MathMin(bar+wing,bars-2), bR=MathMax(bar-wing,0);
   datetime tL=iTime(_Symbol,_Period,bL), tR=iTime(_Symbol,_Period,bR);
   if(tL==0||tR==0||tL>=tR) return;
   ObjectCreate(0,nm,OBJ_RECTANGLE,0,tL,price+pip*4,tR,price-pip*4);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);   ObjectSetInteger(0,nm,OBJPROP_FILL,false);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);     ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   if(StringLen(label)>0)
   {
      bool isHi=(clr==InpColSwHigh);
      datetime tM=iTime(_Symbol,_Period,bar); if(tM==0){ ChartRedraw(0); return; }
      double lblP=isHi?price+pip*10:price-pip*10;
      string lnm=nm+"_LBL";
      ObjectCreate(0,lnm,OBJ_TEXT,0,tM,lblP);
      ObjectSetString (0,lnm,OBJPROP_TEXT,label); ObjectSetString(0,lnm,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,lnm,OBJPROP_FONTSIZE,9);  ObjectSetInteger(0,lnm,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,lnm,OBJPROP_ANCHOR,isHi?ANCHOR_LOWER:ANCHOR_UPPER);
      ObjectSetInteger(0,lnm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
      ObjectSetInteger(0,lnm,OBJPROP_SELECTABLE,false);
   }
   ChartRedraw(0);
}

void DrawTrendline()
{
   string nm="AJTG_TL"; ObjectDelete(0,nm);
   datetime t1=iTime(_Symbol,_Period,g_tl_bar1), t2=iTime(_Symbol,_Period,g_tl_bar2);
   if(t1==0||t2==0||t1>=t2) return;
   ObjectCreate(0,nm,OBJ_TREND,0,t1,g_tl_p1,t2,g_tl_p2);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,g_isUp?InpColTLUp:InpColTLDn);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2); ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ChartRedraw(0);
}

void DrawStep3Box(double h,double l)
{
   string nm="AJTG_S3B"; ObjectDelete(0,nm); double pip=OnePip();
   datetime t1=iTime(_Symbol,_Period,2), t2=iTime(_Symbol,_Period,0);
   if(t1==0||t2==0||t1>=t2) return;
   ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,h+pip*5,t2,l-pip*5);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,InpColS3); ObjectSetInteger(0,nm,OBJPROP_FILL,false);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);        ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ChartRedraw(0);
}

void DrawStep3Label(double h,double l,bool isCont)
{
   string nm="AJTG_S3L"; ObjectDelete(0,nm); double pip=OnePip();
   datetime t=iTime(_Symbol,_Period,1); if(t==0) return;
   double price=(g_dir==DIR_BUY)?l-pip*18:h+pip*18;
   ObjectCreate(0,nm,OBJ_TEXT,0,t,price);
   ObjectSetString (0,nm,OBJPROP_TEXT,isCont?"CONT":"BREAK");
   ObjectSetString (0,nm,OBJPROP_FONT,"Arial Bold"); ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,InpColS3);
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(g_dir==DIR_BUY)?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ChartRedraw(0);
}

// Action line — drawn on BOTH cont and break setups
void DrawActionLine()
{
   string nm="AJTG_AL"; ObjectDelete(0,nm);
   int b1=g_al_b1, b2=g_al_b2; if(b1<=0||b2<0||b1==b2) return;
   datetime t1=iTime(_Symbol,_Period,b1), t2=iTime(_Symbol,_Period,b2);
   if(t1==0||t2==0||t1>=t2) return;
   g_al_t1=t1; g_al_t2=t2;
   ObjectCreate(0,nm,OBJ_TREND,0,t1,g_al_p1,t2,g_al_p2);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,InpColAL);   ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetString (0,nm,OBJPROP_TOOLTIP,"AJTG Action Line"); ChartRedraw(0);
}

// Yellow confirm box — drawn on AL-break candle (CONT setup)
// For BREAK setup the Step3 box already serves as the confirm visual
void DrawConfirmBox(double h,double l)
{
   string nm="AJTG_CFB"; ObjectDelete(0,nm); double pip=OnePip();
   datetime t1=iTime(_Symbol,_Period,2), t2=iTime(_Symbol,_Period,0);
   if(t1==0||t2==0||t1>=t2) return;
   ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,h+pip*4,t2,l-pip*4);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,InpColConfirm); ObjectSetInteger(0,nm,OBJPROP_FILL,false);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);             ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   // label
   string lnm="AJTG_CFL"; ObjectDelete(0,lnm);
   datetime lt=iTime(_Symbol,_Period,1); if(lt==0){ ChartRedraw(0); return; }
   double lp=(g_dir==DIR_BUY)?l-pip*18:h+pip*18;
   ObjectCreate(0,lnm,OBJ_TEXT,0,lt,lp);
   ObjectSetString (0,lnm,OBJPROP_TEXT,"CONFIRM");    ObjectSetString(0,lnm,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,lnm,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,lnm,OBJPROP_COLOR,InpColConfirm);
   ObjectSetInteger(0,lnm,OBJPROP_ANCHOR,(g_dir==DIR_BUY)?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,lnm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,lnm,OBJPROP_SELECTABLE,false);  ChartRedraw(0);
}

void DrawEZBox()
{
   string nm="AJTG_EZ"; ObjectDelete(0,nm);
   datetime t1=iTime(_Symbol,_Period,2);
   datetime t2=iTime(_Symbol,_Period,0)+(datetime)PeriodSeconds(_Period)*10;
   if(t1==0) return;
   ObjectCreate(0,nm,OBJ_RECTANGLE,0,t1,g_ezH,t2,g_ezL);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,InpColEZ); ObjectSetInteger(0,nm,OBJPROP_FILL,true);
   ObjectSetInteger(0,nm,OBJPROP_BACK,true);      ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   string lnm="AJTG_EZL"; ObjectDelete(0,lnm);
   datetime lt=iTime(_Symbol,_Period,1); if(lt==0) return;
   ObjectCreate(0,lnm,OBJ_TEXT,0,lt,g_ezH+OnePip()*12);
   ObjectSetString (0,lnm,OBJPROP_TEXT,"ENTRY ZONE"); ObjectSetString(0,lnm,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,lnm,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,lnm,OBJPROP_COLOR,InpColEZ); ObjectSetInteger(0,lnm,OBJPROP_ANCHOR,ANCHOR_LOWER);
   ObjectSetInteger(0,lnm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,lnm,OBJPROP_SELECTABLE,false);  ChartRedraw(0);
}

void DrawEntryLabel(int bar,bool conservative)
{
   g_objId++;
   string nm="AJTG_ENT_"+IntegerToString(g_objId); double pip=OnePip();
   color  clr=conservative?InpColCons:InpColAgg;
   string txt;
   if(conservative) txt=(g_dir==DIR_BUY)?"▲ CONS BUY":"▼ CONS SELL";
   else             txt=(g_dir==DIR_BUY)?"▲ AGG BUY" :"▼ AGG SELL";
   datetime t=iTime(_Symbol,_Period,bar); if(t==0) return;
   double price=(g_dir==DIR_BUY)?iLow(_Symbol,_Period,bar)-pip*16:iHigh(_Symbol,_Period,bar)+pip*16;
   ObjectCreate(0,nm,OBJ_TEXT,0,t,price);
   ObjectSetString (0,nm,OBJPROP_TEXT,txt);       ObjectSetString(0,nm,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,10);    ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(g_dir==DIR_BUY)?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ChartRedraw(0);
}

//==========================================================================
//  NEW SETUP BUTTON
//==========================================================================
void CreateNewSetupButton()
{
   ObjectDelete(0,BTN_NEWSETUP);
   ObjectCreate(0,BTN_NEWSETUP,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_XDISTANCE,2);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_YDISTANCE,320);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_XSIZE,175);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_YSIZE,26);
   ObjectSetString (0,BTN_NEWSETUP,OBJPROP_TEXT,"🔄 NEW SETUP");
   ObjectSetString (0,BTN_NEWSETUP,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_BGCOLOR,C'0,80,160');
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_BORDER_COLOR,C'0,120,220');
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_ZORDER,10);
   ObjectSetInteger(0,BTN_NEWSETUP,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ChartRedraw(0);
}

//==========================================================================
//  FULL RESET
//==========================================================================
void FullReset(bool deleteSignalObjects)
{
   g_st=ST_SCAN; g_dir=DIR_NONE; g_setup=SETUP_NONE; g_isUp=false;
   g_tl_bar1=g_tl_bar2=0; g_tl_p1=g_tl_p2=0; g_bars_elapsed=0;
   g_between_extreme=0; g_between_bar=0;
   g_touch3_bar=0; g_touch3_h=g_touch3_l=0;
   g_al_b1=g_al_b2=0; g_al_p1=g_al_p2=0; g_al_t1=0; g_al_t2=0;
   g_ezDone=false; g_ezH=g_ezL=0; g_pushed=false;
   g_ticket=0; g_cooldown=0; g_objId=0;

   if(deleteSignalObjects)
   {
      string sig[]=
      {
         "AJTG_SL1","AJTG_SL1_LBL","AJTG_SH_MID","AJTG_SH_MID_LBL",
         "AJTG_SL2","AJTG_SL2_LBL","AJTG_SH1","AJTG_SH1_LBL",
         "AJTG_SL_MID","AJTG_SL_MID_LBL","AJTG_SH2","AJTG_SH2_LBL",
         "AJTG_TL","AJTG_S3B","AJTG_S3L","AJTG_AL",
         "AJTG_CFB","AJTG_CFL",          // confirm box + label
         "AJTG_EZ","AJTG_EZL"
      };
      for(int i=0;i<20;i++) ObjectDelete(0,sig[i]);
      for(int i=1;i<=g_objId+10;i++) ObjectDelete(0,"AJTG_ENT_"+IntegerToString(i));
      ChartRedraw(0);
   }
}

//==========================================================================
//  TRADE LEVEL LINES
//==========================================================================
void PlotLevels(ulong tk,double sl,double tp1,double tp2,double tp3)
{
   string px="AJTG_"+IntegerToString(tk)+"_";
   string tags[4]={"SL","TP1","TP2","TP3"};
   double prices[4]={sl,tp1,tp2,tp3};
   color  clrs[4]={clrRed,clrLime,clrDodgerBlue,clrGold};
   double pip=OnePip(); datetime lbt=TimeCurrent()+(datetime)(PeriodSeconds()*4);
   for(int i=0;i<4;i++)
   {
      string ln=px+tags[i]; ObjectDelete(0,ln);
      ObjectCreate(0,ln,OBJ_HLINE,0,0,prices[i]);
      ObjectSetInteger(0,ln,OBJPROP_COLOR,clrs[i]); ObjectSetInteger(0,ln,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,ln,OBJPROP_WIDTH,1);        ObjectSetInteger(0,ln,OBJPROP_BACK,true);
      ObjectSetInteger(0,ln,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
      string lb=px+tags[i]+"_L"; ObjectDelete(0,lb);
      ObjectCreate(0,lb,OBJ_TEXT,0,lbt,prices[i]+pip*3);
      ObjectSetString (0,lb,OBJPROP_TEXT,tags[i]);  ObjectSetString(0,lb,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,lb,OBJPROP_FONTSIZE,9);    ObjectSetInteger(0,lb,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,lb,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0,lb,OBJPROP_BACK,false);    ObjectSetInteger(0,lb,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lb,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   }
   ChartRedraw(0);
}
void UpdateSLLine(ulong tk,double sl){ string ln="AJTG_"+IntegerToString(tk)+"_SL",lb="AJTG_"+IntegerToString(tk)+"_SL_L"; ObjectSetDouble(0,ln,OBJPROP_PRICE,sl); ObjectMove(0,lb,0,TimeCurrent()+(datetime)(PeriodSeconds()*4),sl+OnePip()*3); ObjectSetString(0,lb,OBJPROP_TEXT,"SL"); ChartRedraw(0); }
void RemoveLevels(ulong tk){ string px="AJTG_"+IntegerToString(tk)+"_"; string tags[]={"SL","TP1","TP2","TP3"}; for(int i=0;i<4;i++){ ObjectDelete(0,px+tags[i]); ObjectDelete(0,px+tags[i]+"_L"); } ChartRedraw(0); }
void UpdateTPLabels(){ datetime lbt=TimeCurrent()+(datetime)(PeriodSeconds()*4); double pip=OnePip(); for(int i=0;i<PositionsTotal();i++){ ulong tk=PositionGetTicket(i); if(tk==0||!PositionSelectByTicket(tk)) continue; string id=IntegerToString(tk); if(!GlobalVariableCheck("AJTG_T1_"+id)) continue; string px="AJTG_"+id+"_"; string tags[]={"SL","TP1","TP2","TP3"},gvk[]={"SL","T1","T2","T3"}; for(int j=0;j<4;j++){ string lb=px+tags[j]+"_L"; if(ObjectFind(0,lb)<0) continue; ObjectMove(0,lb,0,lbt,GlobalVariableGet("AJTG_"+gvk[j]+"_"+id)+pip*3); } } }

//==========================================================================
//  CANDLE TIMER
//==========================================================================
void UpdateTimer()
{
   int p=PeriodSeconds(),rem=p-(int)(TimeCurrent()%p),h=rem/3600,m=(rem%3600)/60,s=rem%60;
   string ts=h>0?StringFormat("%d:%02d:%02d",h,m,s):StringFormat("%02d:%02d",m,s);
   color fg=(rem<=15)?clrTomato:clrLimeGreen;
   string bgn="AJTG_TimerBG";
   if(ObjectFind(0,bgn)<0){ ObjectCreate(0,bgn,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bgn,OBJPROP_CORNER,CORNER_RIGHT_UPPER); ObjectSetInteger(0,bgn,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); ObjectSetInteger(0,bgn,OBJPROP_XDISTANCE,4); ObjectSetInteger(0,bgn,OBJPROP_YDISTANCE,8); ObjectSetInteger(0,bgn,OBJPROP_XSIZE,130); ObjectSetInteger(0,bgn,OBJPROP_YSIZE,38); ObjectSetInteger(0,bgn,OBJPROP_BGCOLOR,clrWhite); ObjectSetInteger(0,bgn,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,bgn,OBJPROP_COLOR,C'200,200,200'); ObjectSetInteger(0,bgn,OBJPROP_WIDTH,1); ObjectSetInteger(0,bgn,OBJPROP_BACK,false); ObjectSetInteger(0,bgn,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,bgn,OBJPROP_ZORDER,10); ObjectSetInteger(0,bgn,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS); }
   string on="AJTG_CandleTimer";
   if(ObjectFind(0,on)<0){ ObjectCreate(0,on,OBJ_LABEL,0,0,0); ObjectSetInteger(0,on,OBJPROP_CORNER,CORNER_RIGHT_UPPER); ObjectSetInteger(0,on,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); ObjectSetInteger(0,on,OBJPROP_XDISTANCE,14); ObjectSetInteger(0,on,OBJPROP_YDISTANCE,14); ObjectSetInteger(0,on,OBJPROP_FONTSIZE,16); ObjectSetString(0,on,OBJPROP_FONT,"Courier New Bold"); ObjectSetInteger(0,on,OBJPROP_BACK,false); ObjectSetInteger(0,on,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,on,OBJPROP_ZORDER,11); ObjectSetInteger(0,on,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS); }
   ObjectSetInteger(0,on,OBJPROP_COLOR,fg); ObjectSetString(0,on,OBJPROP_TEXT,"⏱ "+ts); ChartRedraw(0);
}
void RemoveTimer(){ ObjectDelete(0,"AJTG_CandleTimer"); ObjectDelete(0,"AJTG_TimerBG"); ChartRedraw(0); }

//==========================================================================
//  PIP DISTANCE PANEL
//==========================================================================
bool IsMini(){return GlobalVariableCheck(MP_STATE)&&GlobalVariableGet(MP_STATE)==1.0;}
void SetMini(bool m){GlobalVariableSet(MP_STATE,m?1.0:0.0);}
void UpdatePanelVis(){ bool mini=IsMini(); string hid[]={MP_SL_L,MP_TP1_L,MP_TP2_L,MP_TP3_L,MP_SL_E,MP_TP1_E,MP_TP2_E,MP_TP3_E,MP_BTN,MP_GSEP,MP_GTIT,MP_GSL_L,MP_GTP1_L,MP_GTP2_L,MP_GTP3_L,MP_GSL_E,MP_GTP1_E,MP_GTP2_E,MP_GTP3_E}; for(int i=0;i<19;i++) if(ObjectFind(0,hid[i])>=0) ObjectSetInteger(0,hid[i],OBJPROP_TIMEFRAMES,mini?OBJ_NO_PERIODS:OBJ_ALL_PERIODS); ObjectSetInteger(0,MP_BG,OBJPROP_YSIZE,mini?30:260); ObjectSetString(0,MP_MIN,OBJPROP_TEXT,mini?"▼":"▲"); ChartRedraw(0); }
void CreatePanel()
{
   int px=2,py=52,bw=175,rh=20,gap=2;
   if(ObjectFind(0,MP_BG)<0){ObjectCreate(0,MP_BG,OBJ_RECTANGLE_LABEL,0,0,0);ObjectSetInteger(0,MP_BG,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,MP_BG,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,MP_BG,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,MP_BG,OBJPROP_COLOR,C'80,80,80');ObjectSetInteger(0,MP_BG,OBJPROP_WIDTH,1);ObjectSetInteger(0,MP_BG,OBJPROP_BACK,false);ObjectSetInteger(0,MP_BG,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,MP_BG,OBJPROP_ZORDER,10);ObjectSetInteger(0,MP_BG,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}
   ObjectSetInteger(0,MP_BG,OBJPROP_BGCOLOR,C'40,40,40');ObjectSetInteger(0,MP_BG,OBJPROP_XDISTANCE,px);ObjectSetInteger(0,MP_BG,OBJPROP_YDISTANCE,py);ObjectSetInteger(0,MP_BG,OBJPROP_XSIZE,bw);ObjectSetInteger(0,MP_BG,OBJPROP_YSIZE,260);
   string fxL[]={MP_TITLE,MP_SL_L,MP_TP1_L,MP_TP2_L,MP_TP3_L},fxT[]={"  Forex Pip Distances","  SL:","  TP1:","  TP2:","  TP3:"},fxE[]={MP_SL_E,MP_TP1_E,MP_TP2_E,MP_TP3_E};
   int iy=py+6;
   for(int i=0;i<5;i++){if(ObjectFind(0,fxL[i])<0){ObjectCreate(0,fxL[i],OBJ_LABEL,0,0,0);ObjectSetInteger(0,fxL[i],OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,fxL[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,fxL[i],OBJPROP_BACK,false);ObjectSetInteger(0,fxL[i],OBJPROP_SELECTABLE,false);ObjectSetString(0,fxL[i],OBJPROP_FONT,i==0?"Arial Bold":"Arial");ObjectSetInteger(0,fxL[i],OBJPROP_FONTSIZE,i==0?8:7);ObjectSetInteger(0,fxL[i],OBJPROP_ZORDER,10);ObjectSetInteger(0,fxL[i],OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}ObjectSetInteger(0,fxL[i],OBJPROP_XDISTANCE,px+2);ObjectSetInteger(0,fxL[i],OBJPROP_YDISTANCE,iy+3);ObjectSetInteger(0,fxL[i],OBJPROP_COLOR,i==0?C'0,180,255':i==1?clrTomato:i==2?clrLime:i==3?clrDodgerBlue:clrGold);ObjectSetString(0,fxL[i],OBJPROP_TEXT,fxT[i]);iy+=rh+gap;}
   for(int i=0;i<4;i++){if(ObjectFind(0,fxE[i])<0){ObjectCreate(0,fxE[i],OBJ_EDIT,0,0,0);ObjectSetInteger(0,fxE[i],OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,fxE[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,fxE[i],OBJPROP_BACK,false);ObjectSetInteger(0,fxE[i],OBJPROP_FONTSIZE,7);ObjectSetString(0,fxE[i],OBJPROP_FONT,"Arial");ObjectSetInteger(0,fxE[i],OBJPROP_BGCOLOR,C'25,25,40');ObjectSetInteger(0,fxE[i],OBJPROP_COLOR,clrWhite);ObjectSetInteger(0,fxE[i],OBJPROP_BORDER_COLOR,C'80,80,120');ObjectSetInteger(0,fxE[i],OBJPROP_ZORDER,10);ObjectSetInteger(0,fxE[i],OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}ObjectSetInteger(0,fxE[i],OBJPROP_XDISTANCE,px+65);ObjectSetInteger(0,fxE[i],OBJPROP_YDISTANCE,py+6+(rh+gap)+i*(rh+gap));ObjectSetInteger(0,fxE[i],OBJPROP_XSIZE,bw-67);ObjectSetInteger(0,fxE[i],OBJPROP_YSIZE,rh);}
   iy=py+6+5*(rh+gap)+2;
   string gL[]={MP_GSEP,MP_GTIT,MP_GSL_L,MP_GTP1_L,MP_GTP2_L,MP_GTP3_L},gT[]={"","  Gold Pip Distances","  SL:","  TP1:","  TP2:","  TP3:"},gE[]={MP_GSL_E,MP_GTP1_E,MP_GTP2_E,MP_GTP3_E};
   for(int i=0;i<6;i++){if(ObjectFind(0,gL[i])<0){ObjectCreate(0,gL[i],OBJ_LABEL,0,0,0);ObjectSetInteger(0,gL[i],OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,gL[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,gL[i],OBJPROP_BACK,false);ObjectSetInteger(0,gL[i],OBJPROP_SELECTABLE,false);ObjectSetString(0,gL[i],OBJPROP_FONT,i==1?"Arial Bold":"Arial");ObjectSetInteger(0,gL[i],OBJPROP_FONTSIZE,i<=1?8:7);ObjectSetInteger(0,gL[i],OBJPROP_ZORDER,10);ObjectSetInteger(0,gL[i],OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}ObjectSetInteger(0,gL[i],OBJPROP_XDISTANCE,px+2);ObjectSetInteger(0,gL[i],OBJPROP_YDISTANCE,iy+3);ObjectSetInteger(0,gL[i],OBJPROP_COLOR,i==0?C'80,80,80':i==1?clrGold:i==2?clrTomato:i==3?clrLime:i==4?clrDodgerBlue:clrGold);ObjectSetString(0,gL[i],OBJPROP_TEXT,i==0?"  ─────────────────":gT[i]);iy+=rh+gap;}
   for(int i=0;i<4;i++){if(ObjectFind(0,gE[i])<0){ObjectCreate(0,gE[i],OBJ_EDIT,0,0,0);ObjectSetInteger(0,gE[i],OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,gE[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,gE[i],OBJPROP_BACK,false);ObjectSetInteger(0,gE[i],OBJPROP_FONTSIZE,7);ObjectSetString(0,gE[i],OBJPROP_FONT,"Arial");ObjectSetInteger(0,gE[i],OBJPROP_BGCOLOR,C'40,25,10');ObjectSetInteger(0,gE[i],OBJPROP_COLOR,clrWhite);ObjectSetInteger(0,gE[i],OBJPROP_BORDER_COLOR,C'140,100,40');ObjectSetInteger(0,gE[i],OBJPROP_ZORDER,10);ObjectSetInteger(0,gE[i],OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}ObjectSetInteger(0,gE[i],OBJPROP_XDISTANCE,px+65);ObjectSetInteger(0,gE[i],OBJPROP_YDISTANCE,py+6+7*(rh+gap)+2+i*(rh+gap));ObjectSetInteger(0,gE[i],OBJPROP_XSIZE,bw-67);ObjectSetInteger(0,gE[i],OBJPROP_YSIZE,rh);}
   if(ObjectFind(0,MP_BTN)<0){ObjectCreate(0,MP_BTN,OBJ_BUTTON,0,0,0);ObjectSetInteger(0,MP_BTN,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,MP_BTN,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,MP_BTN,OBJPROP_BACK,false);ObjectSetInteger(0,MP_BTN,OBJPROP_ZORDER,10);ObjectSetInteger(0,MP_BTN,OBJPROP_FONTSIZE,9);ObjectSetString(0,MP_BTN,OBJPROP_FONT,"Arial Bold");ObjectSetString(0,MP_BTN,OBJPROP_TEXT,"✔ Apply");ObjectSetInteger(0,MP_BTN,OBJPROP_COLOR,clrWhite);ObjectSetInteger(0,MP_BTN,OBJPROP_BGCOLOR,C'0,120,60');ObjectSetInteger(0,MP_BTN,OBJPROP_BORDER_COLOR,C'0,160,80');ObjectSetInteger(0,MP_BTN,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}
   ObjectSetInteger(0,MP_BTN,OBJPROP_XDISTANCE,px+2);ObjectSetInteger(0,MP_BTN,OBJPROP_YDISTANCE,iy+1);ObjectSetInteger(0,MP_BTN,OBJPROP_XSIZE,bw-4);ObjectSetInteger(0,MP_BTN,OBJPROP_YSIZE,rh+2);
   if(ObjectFind(0,MP_MIN)<0){ObjectCreate(0,MP_MIN,OBJ_BUTTON,0,0,0);ObjectSetInteger(0,MP_MIN,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,MP_MIN,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);ObjectSetInteger(0,MP_MIN,OBJPROP_BACK,false);ObjectSetInteger(0,MP_MIN,OBJPROP_FONTSIZE,8);ObjectSetString(0,MP_MIN,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,MP_MIN,OBJPROP_COLOR,clrWhite);ObjectSetInteger(0,MP_MIN,OBJPROP_BGCOLOR,C'60,60,60');ObjectSetInteger(0,MP_MIN,OBJPROP_BORDER_COLOR,C'100,100,100');ObjectSetInteger(0,MP_MIN,OBJPROP_ZORDER,10);ObjectSetInteger(0,MP_MIN,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,MP_MIN,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);}
   ObjectSetInteger(0,MP_MIN,OBJPROP_XDISTANCE,px+bw-22);ObjectSetInteger(0,MP_MIN,OBJPROP_YDISTANCE,py+3);ObjectSetInteger(0,MP_MIN,OBJPROP_XSIZE,18);ObjectSetInteger(0,MP_MIN,OBJPROP_YSIZE,18);ObjectSetString(0,MP_MIN,OBJPROP_TEXT,IsMini()?"▼":"▲");
   UpdatePanelVis(); ChartRedraw(0);
}
void PopulatePanel(){ ObjectSetString(0,MP_SL_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_FX_SL",InpSLFx),1)); ObjectSetString(0,MP_TP1_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_FX_TP1",InpTP1Fx),1)); ObjectSetString(0,MP_TP2_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_FX_TP2",InpTP2Fx),1)); ObjectSetString(0,MP_TP3_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_FX_TP3",InpTP3Fx),1)); ObjectSetString(0,MP_GSL_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_GD_SL",InpSLGold),1)); ObjectSetString(0,MP_GTP1_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_GD_TP1",InpTP1Gold),1)); ObjectSetString(0,MP_GTP2_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_GD_TP2",InpTP2Gold),1)); ObjectSetString(0,MP_GTP3_E,OBJPROP_TEXT,DoubleToString(GVget("AJTG_OVR_GD_TP3",InpTP3Gold),1)); if(IsMini()) UpdatePanelVis(); ChartRedraw(0); }
void ApplyPanel(){ double fxSL=StringToDouble(ObjectGetString(0,MP_SL_E,OBJPROP_TEXT)),fxTP1=StringToDouble(ObjectGetString(0,MP_TP1_E,OBJPROP_TEXT)),fxTP2=StringToDouble(ObjectGetString(0,MP_TP2_E,OBJPROP_TEXT)),fxTP3=StringToDouble(ObjectGetString(0,MP_TP3_E,OBJPROP_TEXT)); if(fxSL>0)GlobalVariableSet("AJTG_OVR_FX_SL",fxSL); if(fxTP1>0)GlobalVariableSet("AJTG_OVR_FX_TP1",fxTP1); if(fxTP2>0)GlobalVariableSet("AJTG_OVR_FX_TP2",fxTP2); if(fxTP3>0)GlobalVariableSet("AJTG_OVR_FX_TP3",fxTP3); double gSL=StringToDouble(ObjectGetString(0,MP_GSL_E,OBJPROP_TEXT)),gTP1=StringToDouble(ObjectGetString(0,MP_GTP1_E,OBJPROP_TEXT)),gTP2=StringToDouble(ObjectGetString(0,MP_GTP2_E,OBJPROP_TEXT)),gTP3=StringToDouble(ObjectGetString(0,MP_GTP3_E,OBJPROP_TEXT)); if(gSL>0)GlobalVariableSet("AJTG_OVR_GD_SL",gSL); if(gTP1>0)GlobalVariableSet("AJTG_OVR_GD_TP1",gTP1); if(gTP2>0)GlobalVariableSet("AJTG_OVR_GD_TP2",gTP2); if(gTP3>0)GlobalVariableSet("AJTG_OVR_GD_TP3",gTP3); ObjectSetInteger(0,MP_BTN,OBJPROP_STATE,false); ChartRedraw(0); }
void RemovePanel(){ string o[]={MP_BG,MP_TITLE,MP_SL_L,MP_TP1_L,MP_TP2_L,MP_TP3_L,MP_SL_E,MP_TP1_E,MP_TP2_E,MP_TP3_E,MP_BTN,MP_MIN,MP_GSEP,MP_GTIT,MP_GSL_L,MP_GTP1_L,MP_GTP2_L,MP_GTP3_L,MP_GSL_E,MP_GTP1_E,MP_GTP2_E,MP_GTP3_E}; for(int i=0;i<22;i++) ObjectDelete(0,o[i]); GlobalVariableDel(MP_STATE); ObjectDelete(0,BTN_NEWSETUP); ChartRedraw(0); }

//==========================================================================
//  UTILITY
//==========================================================================
double OnePip(){ return GetPipSize(_Symbol); }
double GetPipSize(const string sym){ int d=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS); double pt=SymbolInfoDouble(sym,SYMBOL_POINT); if(IsGold(sym)&&d==3) return pt*100.0; return (d==5||d==3||d==2)?pt*10.0:pt; }
bool   IsGold(const string sym){ return StringFind(sym,"XAU")>=0||StringFind(sym,"GOLD")>=0||StringFind(sym,"XAG")>=0||StringFind(sym,"GLD")>=0; }
double GetRSI(int shift){ double buf[]; ArraySetAsSeries(buf,true); if(CopyBuffer(g_rsiHnd,0,0,shift+2,buf)<=shift) return 50; return buf[shift]; }
bool PartialClose(ulong tk,const string sym,double vol,bool isB){ if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false; double price=isB?SymbolInfoDouble(sym,SYMBOL_BID):SymbolInfoDouble(sym,SYMBOL_ASK); int d=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS),ff=(int)SymbolInfoInteger(sym,SYMBOL_FILLING_MODE); ENUM_ORDER_TYPE_FILLING fill; if((ff&(int)SYMBOL_FILLING_IOC)!=0) fill=ORDER_FILLING_IOC; else if((ff&(int)SYMBOL_FILLING_FOK)!=0) fill=ORDER_FILLING_FOK; else fill=ORDER_FILLING_RETURN; MqlTradeRequest req={}; MqlTradeResult res={}; req.action=TRADE_ACTION_DEAL; req.position=tk; req.symbol=sym; req.volume=NormalizeDouble(vol,2); req.type=isB?ORDER_TYPE_SELL:ORDER_TYPE_BUY; req.price=NormalizeDouble(price,d); req.deviation=30; req.type_filling=fill; req.comment="AJTG partial"; bool ok=OrderSend(req,res); if(!ok||(res.retcode!=TRADE_RETCODE_DONE&&res.retcode!=TRADE_RETCODE_PLACED)){ Print("❌ PartialClose Ret=",res.retcode); return false; } return true; }
bool ModSLTP(ulong tk,const string sym,double sl,double tp){ if(!PositionSelectByTicket(tk)) return false; int d=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS); CTrade ct; ct.SetDeviationInPoints(30); ct.SetAsyncMode(false); return ct.PositionModify(tk,NormalizeDouble(sl,d),NormalizeDouble(tp,d)); }
bool ModSL(ulong tk,const string sym,double sl){ if(!PositionSelectByTicket(tk)) return false; int d=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS); CTrade ct; ct.SetDeviationInPoints(30); ct.SetAsyncMode(false); return ct.PositionModify(tk,NormalizeDouble(sl,d),PositionGetDouble(POSITION_TP)); }
double CalcVol(const string sym,double lots,double pct){ double minL=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN),step=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP); if(step<=0)step=0.01; if(minL<=0)minL=0.01; double v=NormalizeDouble(MathMax(minL,MathMin(MathFloor(lots*pct/100.0/step)*step,NormalizeDouble(lots-minL,2))),2); return (v>=minL)?v:0; }
double GVget(string key,double def){ return GlobalVariableCheck(key)?GlobalVariableGet(key):def; }
void Throttle(string msg){ if(TimeCurrent()-g_lastPrint>3600){Print(msg);g_lastPrint=TimeCurrent();} }
//+------------------------------------------------------------------+
