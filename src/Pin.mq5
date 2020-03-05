//+------------------------------------------------------------------+
//|                                                          Pin.mq5 |
//|                                       Copyright 2018, Nohros Inc |
//|                                           https://www.nohros.com |
//|                                                                  |
//| This indicator detects pin bars, which is a type of reversal     |
//| signal                                                           |
//+------------------------------------------------------------------+
#property copyright "2018-2018, Nohros Inc."
#property link      "http://www.nohros.com"

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "Sell"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed

#property indicator_label2  "Buy"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrDodgerBlue

#property indicator_label3  "Ratio"
#property indicator_type3   DRAW_NONE
#property indicator_color3  clrDodgerBlue

input double ratio_ = 1.5; // Ratio (Tail/Length)
input int volume_shift_ = 20; // Volume Shift
input int candle_shift_ = 4; // Candle Shift
input int holding_ = 0; // Holding

double sell_[];
double buy_[];

double ratios_[];

int OnInit() {
   SetIndexBuffer(0, sell_, INDICATOR_DATA);
   SetIndexBuffer(1, buy_, INDICATOR_DATA);
   SetIndexBuffer(2, ratios_,INDICATOR_DATA);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits+1);
     
   IndicatorSetString(INDICATOR_SHORTNAME,"Pin("+string(ratio_)+")");
   
   PlotIndexSetInteger(0, PLOT_ARROW, 242);
   PlotIndexSetInteger(1, PLOT_ARROW, 241);
     
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -10);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 10);
   
   ArrayInitialize(sell_, 0.0);
   ArrayInitialize(buy_, 0.0);
   ArrayInitialize(ratios_, 0.0);
      
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
     ComputeRatio(i, open, high, low, close);
     SetSignal(i, open, high, low, close, volume);
     HoldSignal(i);
   }
     
   return(rates_total);
}

void ComputeRatio(const int i, const double &open[], const double &high[], const double &low[], const double &close[]) {
  // We need to compute the ratio between the bars tail
  // and the remaining bar's part. The position of the
  // open price will be used to identify which tail
  // we need to use
  //
  // If open price is greater than the middle of the
  // bar, we should use the lower tail
  //
  // If open price is lower than the middle of the
  // bar, we should use the upper tail
  //
  // If open prices is exactly at the middle of the bar
  // we have no pinbar formation and can return right away
  double tail = 0.0;
  double remaining = 0.0;

  double middle = (high[i]+low[i])/2.0;
  if (open[i] > middle) {
    tail =
      (close[i] > open[i])
        ? (open[i]-low[i])
        : (close[i]-low[i]);

    remaining =
      (close[i] > open[i])
        ? (high[i]-open[i])
        : (high[i]-close[i]);
  } else if (open[i] < middle) {
    tail =
      (close[i] > open[i])
        ? (high[i]-close[i])
        : (high[i]-open[i]);

    remaining =
      (close[i] > open[i])
        ? (close[i]-low[i])
        : (open[i]-low[i]);
  } else {
    tail = 0.0;
    remaining = 0.0;
  }
  
  if (remaining == 0.0) {
    ratios_[i] = (tail > 0) ? 1.0 : 0.0;
    return;
  }
  
  ratios_[i] = tail/remaining;
}

void SetSignal(const int i, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[]) {
  buy_[i] = 0.0;
  sell_[i] = 0.0;
  
  if (ratios_[i] < ratio_ || i < volume_shift_ || i < candle_shift_) {
    return;    
  }
   
  // A pin bar should have the gratest volume of the
  // last [shift] bars
  long sum = 0.0;
  for (int j = 1; j < volume_shift_; ++j) {
    sum += volume[i-j];
  }
  
  double mean = sum*1.0 / volume_shift_;
  if (volume[i] < mean) {
    return;
  }  
  
  // There is two type of pin bars, bullish and bearish, the
  // position of the open price will be used to identify
  // which type of pin bar to look for
  //
  // If th open price is greater than the middle of the bar
  // we should look for a "bullish" pin bar
  //
  // If th open price is lower than the middle of the bar
  // we should look for a "bearish" pin bar
  double middle = (high[i]+low[i])/2.0;
  if (open[i] > middle) {
    // For bullish pin bars the low should be the lowet low
    // of the last [volume_shift_] candles and the last
    // [volume_shift_] candles should be bearish
    for (int j = 1; j < candle_shift_; ++j) {
      if (low[i-j] < low[i]) {
        return;
      }
      
      if (close[i-j] > open[i-j]) {
        return;
      }
    }
    
    buy_[i] = low[i];
    sell_[i] = 0.0;
    return;
  }
  
  if (open[i] < middle) {
    // For bearish pin bars the high should be the highest high
    // of the last [volume_shift_] candles and the last
    // [volume_shift_] candles should be bullish
    for (int j = 1; j < candle_shift_; ++j) {
      if (high[i-j] > high[i]) {
        return;
      }
      
      if (close[i-j] < open[i-j]) {
        return;
      }
    }
    
    buy_[i] = 0.0;
    sell_[i] = high[i];
    return;
  }
  
  buy_[i] = 0.0;
  sell_[i] = 0.0;
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