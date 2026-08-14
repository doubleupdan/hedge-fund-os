//+------------------------------------------------------------------+
//| AJTG_SetupAB_Demo.mq5                                             |
//| Minimal demo EA — logs and alerts when Setup A/B + RSI-50 fires.  |
//| Drop this in Strategy Tester against XAUUSD to see real triggers  |
//| before wiring it into your live signal bot / trade manager EAs.  |
//+------------------------------------------------------------------+
#property copyright "AJTG"
#property version   "1.00"
#property strict

#include <AJTG_SetupAB.mqh>

input int    SwingWindow      = 10;     // bars defining prior swing high/low
input int    RSIPeriod        = 14;     // RSI period for the 50-line gate
input double BreakoutBuffer   = 0.002;  // % buffer required for a clean breakout
input bool   AlertOnSignal    = true;   // popup alert when a setup fires
input bool   PrintOnEveryBar  = false;  // verbose: log even "no trigger" bars

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   Print("AJTG_SetupAB_Demo loaded on ", _Symbol, " ", EnumToString((ENUM_TIMEFRAMES)Period()));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBarTime == lastBarTime)
      return; // only evaluate once per new closed bar
   lastBarTime = curBarTime;

   // shift=1 -> evaluate the last CLOSED bar, no lookahead / repaint
   AJTGSignal sig = AJTG_GetSignal(_Symbol, PERIOD_CURRENT, 1,
                                    SwingWindow, RSIPeriod, BreakoutBuffer);

   if(sig.setup == AJTG_NONE)
     {
      if(PrintOnEveryBar)
         Print(TimeToString(curBarTime), " | no signal | ", sig.reason);
      return;
     }

   string msg = StringFormat("%s | %s | conviction %.2f | %s",
                              _Symbol, TimeToString(curBarTime), sig.conviction, sig.reason);
   Print(msg);

   if(AlertOnSignal)
      Alert(msg);

   // --- Wire-up point ---
   // This EA only logs/alerts. To actually trade it, plug sig.direction /
   // sig.conviction into your existing AJTG_TradeManager / AJTG_TradeManager_PH
   // entry logic here (position sizing, SL/TP, partial close rules already
   // live in those EAs — this file's only job is producing the signal).
  }
//+------------------------------------------------------------------+
