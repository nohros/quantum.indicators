//+------------------------------------------------------------------+
//|                                                       Postal.mq5 |
//|                                       Copyright 2018, Nohros Inc |
//|                                           https://www.nohros.com |
//+------------------------------------------------------------------+
#property copyright "2018-2018, Nohros Inc."
#property link      "http://www.nohros.com"

#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   10

#property indicator_label1  "Sell"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrRed

#property indicator_label2  "Buy"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrDodgerBlue

#property indicator_label3  "UpOffset"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DOT

#property indicator_label4  "UpDistance"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed

#property indicator_label5  "DownOffset"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLimeGreen
#property indicator_style5  STYLE_DOT

#property indicator_label6  "DownDistance"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrLimeGreen

#property indicator_label7  "Ema"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrYellow

#property indicator_label8  "Touched"
#property indicator_type8   DRAW_NONE
#property indicator_color8  clrAqua

#property indicator_label9  "Inside"
#property indicator_type9   DRAW_NONE
#property indicator_color9  clrAqua

#property indicator_label10  "ATRs"
#property indicator_type10   DRAW_NONE
#property indicator_color10  clrAqua

input int ema_period_ = 72; // Period
input double distance_ = 400; // Distance
input double offset_ = 50; // Offset
input int holding_ = 3; // Holding
input int touch_ = 1; // Touch
input int mode_ = 0; // Distance Type: 0:Points, 1:Percentage, 2: ATR
input int type_ = 0; // Signal type: 0:Postal, 1:Postal and AntiPostal
int input atr_period_ = 10; // ATR Period

double sell_[];
double buy_[];

double up_offset_[];
double up_distance_[];

double down_offset_[];
double down_distance_[];

double ema_[];
double ema_touched_[];

double inside_[];
double atrs_[];

int ema_handle_;

int atr_handle_;

int OnInit() {
   SetIndexBuffer(0, sell_, INDICATOR_DATA);
   SetIndexBuffer(1, buy_, INDICATOR_DATA);
   SetIndexBuffer(2, up_offset_,INDICATOR_DATA);
   SetIndexBuffer(3, up_distance_,INDICATOR_DATA);
   SetIndexBuffer(4, down_offset_,INDICATOR_DATA);
   SetIndexBuffer(5, down_distance_,INDICATOR_DATA);
   SetIndexBuffer(6, ema_,INDICATOR_DATA);
   SetIndexBuffer(7, ema_touched_,INDICATOR_DATA);
   SetIndexBuffer(8, inside_,INDICATOR_DATA);
   SetIndexBuffer(9, atrs_,INDICATOR_DATA);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+1);
   
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ema_period_-1);
   
   IndicatorSetString(INDICATOR_SHORTNAME,"Postal ("+string(ema_period_)+","+string(distance_)+","+string(offset_)+")");
   
   ArrayInitialize(sell_, 0.0);
   ArrayInitialize(buy_, 0.0);
   ArrayInitialize(up_offset_, 0.0);
   ArrayInitialize(up_distance_, 0.0);
   ArrayInitialize(down_offset_, 0.0);
   ArrayInitialize(down_distance_, 0.0);
   ArrayInitialize(ema_, 0.0);
   ArrayInitialize(ema_touched_, 0.0);
   ArrayInitialize(inside_, 0.0);
   ArrayInitialize(atrs_, 0.0);
   
   ema_handle_ = INVALID_HANDLE;
   ema_handle_ = iMA(NULL, NULL, ema_period_, 0, MODE_EMA, PRICE_CLOSE);
   if (ema_handle_ == INVALID_HANDLE) {
     Print("Failed to get handle of EMA! Error", GetLastError());
     return(INIT_PARAMETERS_INCORRECT);
   }
   
   atr_handle_ = INVALID_HANDLE;
   if (mode_ == 2) {
     atr_handle_ = iMA(NULL, NULL, atr_period_, 0, MODE_EMA, iATR(_Symbol, 0, atr_period_));
     if (atr_handle_ == INVALID_HANDLE) {
       Print("Failed to get handle of EMA! Error", GetLastError());
       return(INIT_PARAMETERS_INCORRECT);
     }
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
     
     if (mode_ == 0) {
       up_distance_[i] = ema_[i] + distance_;
       down_distance_[i] = ema_[i] - distance_;
     } else if (mode_== 1) {
       up_distance_[i] = ema_[i] * (1+ distance_);
       down_distance_[i] = ema_[i] *(1- distance_);
     } else {
       up_distance_[i] = ema_[i] + distance_*atrs_[i];
       down_distance_[i] = ema_[i] - distance_*atrs_[i];
     }
     
     up_offset_[i] = up_distance_[i] - offset_;
     down_offset_[i] = down_distance_[i] + offset_;
     
     if (i == 0) {
       continue;
     }
     
     // The signal can only be set after the EMA is touched for the first
     // time on day.
     bool is_inside = IsInside(i, open, high, low);
     if (!TouchedEma(i, open, high, low)) {
       if (type_ == 1 && !is_inside) {
         SetAntiSignal(i, open, high, low);
         HoldSignal(i);
       } else {
         sell_[i] = 0.0;
         buy_[i] = 0.0;
       }
     } else {
       SetSignal(i, open, high, low);
       HoldSignal(i);
     }
   }
     
   return(rates_total);
}

bool IsInside(const int i, const double &open[], const double &high[], const double &low[]) {
  if (inside_[i-1] == 1.0) {
    inside_[i] = 1.0;
    return true;
  }
  
  // If any candle is inside the postal bands, mark it
  // to interrupt the anti postal signal.  
  if (high[i] < up_offset_[i] && low[i] > down_offset_[i]) {
    inside_[i] = 1.0;
    return true;
  }
  return false;
}

bool TouchedEma(const int i, const double &open[], const double &high[], const double &low[]) {
  if (ema_touched_[i-1] == 1.0 || touch_ == 0) {
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
  if (open[i] < up_offset_[i] && high[i] >= up_offset_[i]) {
    sell_[i] = high[i]+offset_;
    buy_[i] = 0.0;
    return;
  }
  
  if (open[i] > down_offset_[i] && low[i] <= down_offset_[i]) {
    sell_[i] = 0.0;
    buy_[i] = low[i]-offset_;
    return;
  }
    
  sell_[i] = 0.0;
  buy_[i] = 0.0;
}

void SetAntiSignal(const int i, const double &open[], const double &high[], const double &low[]) {
  if (high[i] >= up_offset_[i]) {
    sell_[i] = high[i]+offset_;
    buy_[i] = 0.0;
    return;
  }
  
  if (low[i] <= down_offset_[i]) {
    sell_[i] = 0.0;
    buy_[i] = low[i]-offset_;
    return;
  }
    
  sell_[i] = 0.0;
  buy_[i] = 0.0;
}

void HoldSignal(const int i) {
  if (holding_ > 0 && i > holding_) {
    if (buy_[i-1] > 0.0 && buy_[i-holding_] == 0.0) {
      buy_[i] = buy_[i-1];
      return;
    }

    if (sell_[i-1] > 0.0 && sell_[i-holding_] == 0.0) {
      sell_[i] = sell_[i-1];
      return;
    }
  }
}

int CopyData(const int to_copy) {
  int copied = CopyBuffer(ema_handle_, 0, 0, to_copy, ema_);
  if (copied <=0) {
    Print("Getting EMA failed! Error:", GetLastError());
    return(0);
  }
  
  if (mode_ == 2) {
    copied = CopyBuffer(atr_handle_, 0, 0, to_copy, atrs_);
    if (copied <=0) {
      Print("Getting ATR failed! Error:", GetLastError());
      return(0);
    }
  }
   
  return copied;
}

void ResetOnNewDay(const int i, const datetime &time[]) {
  if (i == 0) {
    ema_touched_[i] = 0.0;
    inside_[i] = 0.0;
    return;
  }
  
  MqlDateTime previous, now;
  TimeToStruct(time[i-1], previous);
  TimeToStruct(time[i], now);
  
  if (previous.day != now.day) {
    ema_touched_[i] = 0.0;
    ema_touched_[i-1] = 0.0;
    inside_[i] = 0.0;
    inside_[i-1] = 0.0;
    sell_[i] = 0.0;
    buy_[i] = 0.0;
  }
}