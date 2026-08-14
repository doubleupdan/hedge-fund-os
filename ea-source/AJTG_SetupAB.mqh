//+------------------------------------------------------------------+
//| AJTG_SetupAB.mqh                                                  |
//| Setup A (trendline bounce) + Setup B (breakout/reversal),         |
//| gated by the zero-tolerance RSI-50 confirmation rule.             |
//|                                                                    |
//| Port of ajtg_setup.py (aihf QuantModel) to native MQL5, so the    |
//| exact same setup logic can run against a live XAUUSD feed and be  |
//| backtested in Strategy Tester.                                    |
//|                                                                    |
//| Usage:                                                             |
//|   #include <AJTG_SetupAB.mqh>                                     |
//|   AJTGSignal sig = AJTG_GetSignal(_Symbol, PERIOD_CURRENT, 1,      |
//|                                    10, 14, 0.002);                 |
//|   if(sig.setup != AJTG_NONE) { ... }                               |
//+------------------------------------------------------------------+
#property strict

//--- Setup classification
enum AJTGSetupType
  {
   AJTG_NONE   = 0,   // no qualifying trigger
   AJTG_SETUP_A = 1,   // trendline bounce / continuation
   AJTG_SETUP_B = 2    // breakout / reversal
  };

//--- Signal result, mirrors the Python Signal object (value, reasoning, metadata)
struct AJTGSignal
  {
   AJTGSetupType  setup;       // AJTG_NONE / AJTG_SETUP_A / AJTG_SETUP_B
   int            direction;   // +1 long, -1 short, 0 none
   double         conviction;  // +1.0 / +0.6 / -1.0 / -0.6 / 0.0 — mirrors Python magnitudes
   double         rsi;         // RSI value used for the RSI-50 gate
   string         reason;      // human-readable, for logs/journal
  };

//+------------------------------------------------------------------+
//| Core: compute the AJTG Setup A/B signal as of a given shift       |
//|                                                                    |
//| symbol           - instrument, e.g. "XAUUSD"                      |
//| tf               - timeframe                                      |
//| shift             - bar shift to evaluate as-of (1 = last closed) |
//| swing_window      - bars used to define prior swing high/low      |
//|                      (matches Python's swing_window, default 10)  |
//| rsi_period        - RSI period (matches Python default 14)        |
//| breakout_buffer   - % buffer required to count as a clean break   |
//|                      (matches Python breakout_buffer_pct, 0.002)  |
//+------------------------------------------------------------------+
AJTGSignal AJTG_GetSignal(const string symbol,
                           const ENUM_TIMEFRAMES tf,
                           const int shift,
                           const int swing_window   = 10,
                           const int rsi_period     = 14,
                           const double breakout_buffer = 0.002)
  {
   AJTGSignal result;
   result.setup      = AJTG_NONE;
   result.direction  = 0;
   result.conviction = 0.0;
   result.rsi         = 50.0;
   result.reason      = "insufficient history";

   int need = swing_window * 2 + shift + rsi_period + 5;
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, shift, need, rates);
   if(copied < swing_window * 2 + 5)
      return result; // not enough bars — abstain, same as Python's neutral()

   // rates[] comes back oldest-first from CopyRates with these params;
   // index copied-1 is the most recent (== `shift` bars back from now).
   ArraySetAsSeries(rates, false);

   // "recent" = last swing_window bars ending at `shift`
   // "prior"  = the swing_window bars before that
   int recentStart = copied - swing_window;
   int priorStart  = recentStart - swing_window;
   if(priorStart < 0)
      return result;

   double swingHigh = -DBL_MAX, swingLow = DBL_MAX;
   for(int i = priorStart; i < recentStart; i++)
     {
      if(rates[i].high > swingHigh) swingHigh = rates[i].high;
      if(rates[i].low  < swingLow)  swingLow  = rates[i].low;
     }

   double lastClose = rates[copied - 1].close;
   double lastHigh  = rates[copied - 1].high;
   double lastLow   = rates[copied - 1].low;
   double recentFirstClose = rates[recentStart].close;

   // --- RSI at this shift ---
   int rsiHandle = iRSI(symbol, tf, rsi_period, PRICE_CLOSE);
   double rsiBuf[];
   double rsi = 50.0;
   if(rsiHandle != INVALID_HANDLE)
     {
      ArraySetAsSeries(rsiBuf, true);
      if(CopyBuffer(rsiHandle, 0, shift, 1, rsiBuf) > 0)
         rsi = rsiBuf[0];
      IndicatorRelease(rsiHandle);
     }
   result.rsi = rsi;

   // --- Setup B: breakout above/below prior swing, with buffer ---
   AJTGSetupType setup = AJTG_NONE;
   int direction = 0;
   string note = "";

   if(lastClose > swingHigh * (1.0 + breakout_buffer))
     {
      setup = AJTG_SETUP_B; direction = 1;
      note = StringFormat("close %.5f broke prior swing high %.5f", lastClose, swingHigh);
     }
   else if(lastClose < swingLow * (1.0 - breakout_buffer))
     {
      setup = AJTG_SETUP_B; direction = -1;
      note = StringFormat("close %.5f broke prior swing low %.5f", lastClose, swingLow);
     }
   else
     {
      // --- Setup A: pullback that holds recent structure ---
      bool trendUp   = lastClose > recentFirstClose;
      bool trendDown = lastClose < recentFirstClose;

      bool nearSupport    = (lastLow  <= swingLow  * 1.01);
      bool heldSupport    = (lastClose > swingLow);
      bool nearResistance = (lastHigh >= swingHigh * 0.99);
      bool heldResistance = (lastClose < swingHigh);

      if(trendUp && nearSupport && heldSupport)
        {
         setup = AJTG_SETUP_A; direction = 1;
         note = StringFormat("pullback held support near %.5f in an uptrend", swingLow);
        }
      else if(trendDown && nearResistance && heldResistance)
        {
         setup = AJTG_SETUP_A; direction = -1;
         note = StringFormat("pullback held resistance near %.5f in a downtrend", swingHigh);
        }
     }

   if(setup == AJTG_NONE)
     {
      result.reason = "no Setup A/B trigger";
      return result;
     }

   // --- Zero-tolerance RSI-50 rule: never override, abstain if unmet ---
   if(direction == 1 && rsi <= 50.0)
     {
      result.reason = StringFormat("%s long trigger but RSI %.1f <= 50 (abstain)",
                                    (setup == AJTG_SETUP_A ? "Setup A" : "Setup B"), rsi);
      return result;
     }
   if(direction == -1 && rsi >= 50.0)
     {
      result.reason = StringFormat("%s short trigger but RSI %.1f >= 50 (abstain)",
                                    (setup == AJTG_SETUP_A ? "Setup A" : "Setup B"), rsi);
      return result;
     }

   double magnitude = (setup == AJTG_SETUP_B) ? 1.0 : 0.6;
   result.setup      = setup;
   result.direction  = direction;
   result.conviction = direction * magnitude;
   result.reason      = StringFormat("%s %s: %s; RSI %.1f confirms",
                                      (setup == AJTG_SETUP_A ? "Setup A" : "Setup B"),
                                      (direction == 1 ? "long" : "short"),
                                      note, rsi);
   return result;
  }
//+------------------------------------------------------------------+
