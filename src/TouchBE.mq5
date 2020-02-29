//+------------------------------------------------------------------+
//|                                                      TouchBE.mq5 |
//|                                       Copyright 2018, Nohros Inc |
//|                                           https://www.nohros.com |
//|                                                                  |
//| This indicator is used to perform a custom trailing bar by bar   |
//| trailing stop, the trailing stop is activated when the price     |
//| touchs a predefined EMA.                                         |
//|                                                                  |
//| You could used this istead of a rigid EMA take profit            |
//+------------------------------------------------------------------+
#property copyright "2018-2018, Nohros Inc."
#property link      "http://www.nohros.com"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "Sell"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrRed

#property indicator_label2  "Buy"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrDodgerBlue

#property indicator_label3  "Ema"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow

#property indicator_label4  "Touched"
#property indicator_type4   DRAW_NONE
#property indicator_color4  clrAqua

input int ema_period_ = 110; // Period
input int delta_ = 30; // Delta
input int magic_ = -1; // Magic

double sell_[];
double buy_[];

double ema_[];
double ema_touched_[];

int ema_handle_;

int OnInit() {
   SetIndexBuffer(0, sell_, INDICATOR_DATA);
   SetIndexBuffer(1, buy_, INDICATOR_DATA);
   SetIndexBuffer(2, ema_,INDICATOR_DATA);
   SetIndexBuffer(3, ema_touched_,INDICATOR_DATA);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+1);
   
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ema_period_-1);
   
   IndicatorSetString(INDICATOR_SHORTNAME,"Touchema("+string(ema_period_)+")");
   
   ArrayInitialize(sell_, 0.0);
   ArrayInitialize(buy_, 0.0);
   ArrayInitialize(ema_, 0.0);
   ArrayInitialize(ema_touched_, 0.0);
   
   ema_handle_ = INVALID_HANDLE;
   ema_handle_ = iMA(NULL, NULL, ema_period_, 0, MODE_EMA, PRICE_CLOSE);
   if (ema_handle_ == INVALID_HANDLE) {
     Print("Failed to get handle of EMA! Error", GetLastError());
     return(INIT_PARAMETERS_INCORRECT);
   }
   
   return(INIT_SUCCEEDED);
}

int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]) {
   
   int start=MathMax(0, prev_calculated-1);
   for (int i = start; i < rates_total; ++i) {
     int to_copy;
     if (prev_calculated > rates_total || prev_calculated <= 0) {
       to_copy = rates_total;
     } else {
       to_copy = rates_total-prev_calculated;
       if (prev_calculated > 0) {
         to_copy++;
       }
     }
     
     int bars = BarsCalculated(ema_handle_);
     if (bars < ema_period_) {
       return(rates_total);
     }
          
     int copied = CopyData(to_copy);
     if (copied <=0) {
       return(rates_total);
     }
     
     ResetOnNewDay(i, time);
          
     if (i == 0) {
       continue;
     }
     
     TouchedEma(i, open, high, low);
     
     SetSignal(i, open, high, low);
   }
     
   return(rates_total);
}

bool TouchedEma(const int i, const double &open[], const double &high[], const double &low[]) {
  if (ema_touched_[i-1] == 1.0) {
    ema_touched_[i] = 1.0;
    return true;
  }
  
  // If the EMA was not touched before, check if it was touched
  // by the current candle.
  if (open[i] > ema_[i] && low[i] <= ema_[i]) {
    ema_touched_[i] = 1.0;
    return true;
  }
  
  if (open[i] < ema_[i] && high[i] >= ema_[i]) {
    ema_touched_[i] = 1.0;
    return true;
  }
  
  ema_touched_[i] = 0.0;
  return false;
}

void SetSignal(const int i, const double &open[], const double &high[], const double &low[]) {   
  if (ema_touched_[i] == 0.0) {
    return;
  }
    
  int position = PositionsTotal();
  if (position == 0) {
    ema_touched_[i] = 0.0;
    return;
  }
  
  // Here we know that the price has touched the
  // average and we are positioned, now we need
  // to know the position direction and compute
  // our BE stop
  double ea_pos = 0;
  long direction = 0;
  for (int j=0; j < position; ++j) {
    ulong ticket = PositionGetTicket(j);
    if (ticket > 0) {
      long magic = PositionGetInteger(POSITION_MAGIC);
      if (magic != magic_) {
        continue;
      }
      
      // Here we know that the current selected
      // position belongs to our EA, so we can sum up
      // its equity
      ea_pos += PositionGetDouble(POSITION_PRICE_OPEN);
      direction = PositionGetInteger(POSITION_TYPE);
    }
  }
  
  if (ea_pos == 0) {
    return;
  }
  
  if (direction == POSITION_TYPE_BUY) {
    buy_[i] = low[i]-delta_;
    sell_[i] = 0.0;
  } else if (direction == POSITION_TYPE_SELL) {
    buy_[i] = 0.0;
    sell_[i] = high[i]+delta_;
  } else {
    buy_[i] = 0.0;
    sell_[i] = 0.0;
  }
}

int CopyData(const int to_copy) {
  int copied = CopyBuffer(ema_handle_, 0, 0, to_copy, ema_);
  if (copied <=0) {
    Print("Getting EMA failed! Error:", GetLastError());
    return(0);
  }
   
  return copied;
}

void ResetOnNewDay(const int i, const datetime &time[]) {
  if (i == 0) {
    ema_touched_[i] = 0.0;
    return;
  }
  
  MqlDateTime previous, now;
  TimeToStruct(time[i-1], previous);
  TimeToStruct(time[i], now);
  
  if (previous.day != now.day) {
    ema_touched_[i] = 0.0;
    ema_touched_[i-1] = 0.0;
    sell_[i] = 0.0;
    buy_[i] = 0.0;
  }
}