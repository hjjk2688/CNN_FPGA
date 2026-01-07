`timescale 1ns / 1ps

module fully_connected #(
    parameter INPUT_NUM = 48,
    parameter OUTPUT_NUM = 10
    ) (
    input                        clk,
    input                        rst_n,
    input                        valid_in,
    input       signed [11:0]    data_in_1,
    input       signed [11:0]    data_in_2,
    input       signed [11:0]    data_in_3,
    input       [2:0]            sw,            
    output reg [3:0]             result_leds, 
    output reg                   valid_out_fc
    );

    // --- State Machine ---
    localparam S_IDLE      = 3'd0;
    localparam S_BUFFERING = 3'd1;
    localparam S_CALC      = 3'd2;
    localparam S_FIND_MAX  = 3'd3;
    localparam S_DONE      = 3'd4;

    reg [2:0] state;
    // 32비트 버퍼 (부호 오염 방지)
    reg signed [31:0] input_buffer [0:47]; 
    reg [5:0] buffer_cnt;
    reg [3:0] neuron_idx;
    reg [5:0] mac_idx;
    reg signed [31:0] mac_sum;
    
    // [중요] signed 필수
    reg signed [31:0] neuron_outputs [0:9];
    
    reg [3:0] find_max_cnt;
    reg signed [31:0] max_val;
    reg [3:0] final_result;

//    integer k;
//    initial begin
//        for (k = 0; k < 48; k = k + 1) input_buffer[k] = 0;
//        for (k = 0; k < 10; k = k + 1) neuron_outputs[k] = 0;
//    end

    // --- Bias Function ---
    function signed [7:0] get_bias(input [3:0] addr);
        case(addr)
            4'd0: get_bias=8'sh1f; 
            4'd1: get_bias=8'sh7f; 
            4'd2: get_bias=8'sh80; 
            4'd3: get_bias=8'sh80; 
            4'd4: get_bias=8'sh7f; 
            4'd5: get_bias=8'sh80; 
            4'd6: get_bias=8'sh7f; 
            4'd7: get_bias=8'shb1; 
            4'd8: get_bias=8'sh3c; 
            4'd9: get_bias=8'sh44; 
            default: get_bias = 8'sh00;
        endcase
    endfunction

    // --- Weight Function (내용 생략 - 기존과 동일하게 두시면 됩니다) ---
  function signed [7:0] get_weight(input [9:0] addr);
    case(addr)

        // --- Neuron 0 ---
        10'd000: get_weight=8'shf2; 10'd001: get_weight=8'shce; 10'd002: get_weight=8'shd0; 10'd003: get_weight=8'sh31;
        10'd004: get_weight=8'sh06; 10'd005: get_weight=8'shd4; 10'd006: get_weight=8'sh26; 10'd007: get_weight=8'shf3;
        10'd008: get_weight=8'shfa; 10'd009: get_weight=8'sh40; 10'd010: get_weight=8'sh46; 10'd011: get_weight=8'sh17;
        10'd012: get_weight=8'shce; 10'd013: get_weight=8'sh80; 10'd014: get_weight=8'sh23; 10'd015: get_weight=8'sh1d;
        10'd016: get_weight=8'shd1; 10'd017: get_weight=8'sh06; 10'd018: get_weight=8'shdf; 10'd019: get_weight=8'she7;
        10'd020: get_weight=8'sh0a; 10'd021: get_weight=8'sh41; 10'd022: get_weight=8'sh25; 10'd023: get_weight=8'shaa;
        10'd024: get_weight=8'shde; 10'd025: get_weight=8'sh80; 10'd026: get_weight=8'sh09; 10'd027: get_weight=8'sh37;
        10'd028: get_weight=8'shc7; 10'd029: get_weight=8'shf1; 10'd030: get_weight=8'sh04; 10'd031: get_weight=8'shfa;
        10'd032: get_weight=8'she4; 10'd033: get_weight=8'sh3a; 10'd034: get_weight=8'sh26; 10'd035: get_weight=8'shae;
        10'd036: get_weight=8'shbc; 10'd037: get_weight=8'sh80; 10'd038: get_weight=8'sh39; 10'd039: get_weight=8'shd8;
        10'd040: get_weight=8'shc9; 10'd041: get_weight=8'sh41; 10'd042: get_weight=8'shcb; 10'd043: get_weight=8'she6;
        10'd044: get_weight=8'sh19; 10'd045: get_weight=8'shf3; 10'd046: get_weight=8'sh0f; 10'd047: get_weight=8'sh2b;

        // --- Neuron 1 ---
        10'd048: get_weight=8'sh50; 10'd049: get_weight=8'shfe; 10'd050: get_weight=8'sha1; 10'd051: get_weight=8'sh0f;
        10'd052: get_weight=8'sh13; 10'd053: get_weight=8'shc8; 10'd054: get_weight=8'sh0b; 10'd055: get_weight=8'sheb;
        10'd056: get_weight=8'sha9; 10'd057: get_weight=8'shf5; 10'd058: get_weight=8'sh88; 10'd059: get_weight=8'shd1;
        10'd060: get_weight=8'sh1e; 10'd061: get_weight=8'sh06; 10'd062: get_weight=8'sh80; 10'd063: get_weight=8'sh3f;
        10'd064: get_weight=8'sh0e; 10'd065: get_weight=8'shf7; 10'd066: get_weight=8'sheb; 10'd067: get_weight=8'shea;
        10'd068: get_weight=8'shb1; 10'd069: get_weight=8'sh05; 10'd070: get_weight=8'she0; 10'd071: get_weight=8'she5;
        10'd072: get_weight=8'sh37; 10'd073: get_weight=8'shc8; 10'd074: get_weight=8'she2; 10'd075: get_weight=8'sh42;
        10'd076: get_weight=8'sh19; 10'd077: get_weight=8'shd2; 10'd078: get_weight=8'sh20; 10'd079: get_weight=8'shd1;
        10'd080: get_weight=8'she3; 10'd081: get_weight=8'shf7; 10'd082: get_weight=8'sh32; 10'd083: get_weight=8'sh07;
        10'd084: get_weight=8'sh1f; 10'd085: get_weight=8'shcb; 10'd086: get_weight=8'sh3d; 10'd087: get_weight=8'sh0d;
        10'd088: get_weight=8'sh23; 10'd089: get_weight=8'sh9e; 10'd090: get_weight=8'sh07; 10'd091: get_weight=8'sh03;
        10'd092: get_weight=8'sh0c; 10'd093: get_weight=8'shf8; 10'd094: get_weight=8'sh29; 10'd095: get_weight=8'she2;

        // --- Neuron 2 ---
        10'd096: get_weight=8'sh3d; 10'd097: get_weight=8'sh57; 10'd098: get_weight=8'sh0d; 10'd099: get_weight=8'sh2f;
        10'd100: get_weight=8'sh38; 10'd101: get_weight=8'shea; 10'd102: get_weight=8'sh34; 10'd103: get_weight=8'sh3e;
        10'd104: get_weight=8'sh0b; 10'd105: get_weight=8'sh23; 10'd106: get_weight=8'sh25; 10'd107: get_weight=8'shb7;
        10'd108: get_weight=8'sh04; 10'd109: get_weight=8'sh3b; 10'd110: get_weight=8'shf0; 10'd111: get_weight=8'shea;
        10'd112: get_weight=8'sh09; 10'd113: get_weight=8'shf0; 10'd114: get_weight=8'she8; 10'd115: get_weight=8'sh30;
        10'd116: get_weight=8'sh0d; 10'd117: get_weight=8'shf3; 10'd118: get_weight=8'shcb; 10'd119: get_weight=8'shc3;
        10'd120: get_weight=8'sh10; 10'd121: get_weight=8'sh36; 10'd122: get_weight=8'sh0f; 10'd123: get_weight=8'she8;
        10'd124: get_weight=8'sh0b; 10'd125: get_weight=8'sheb; 10'd126: get_weight=8'sh00; 10'd127: get_weight=8'sh0d;
        10'd128: get_weight=8'shf2; 10'd129: get_weight=8'shfd; 10'd130: get_weight=8'shfe; 10'd131: get_weight=8'shfd;
        10'd132: get_weight=8'shf5; 10'd133: get_weight=8'sh0d; 10'd134: get_weight=8'sh2a; 10'd135: get_weight=8'shd7;
        10'd136: get_weight=8'shf6; 10'd137: get_weight=8'sheb; 10'd138: get_weight=8'she9; 10'd139: get_weight=8'shd9;
        10'd140: get_weight=8'shf7; 10'd141: get_weight=8'she0; 10'd142: get_weight=8'shf9; 10'd143: get_weight=8'sh76;

        // --- Neuron 3 ---
        10'd144: get_weight=8'sh50; 10'd145: get_weight=8'sh6d; 10'd146: get_weight=8'sh0d; 10'd147: get_weight=8'sh2b;
        10'd148: get_weight=8'sh45; 10'd149: get_weight=8'shed; 10'd150: get_weight=8'sh24; 10'd151: get_weight=8'sh4d;
        10'd152: get_weight=8'sh0c; 10'd153: get_weight=8'sh08; 10'd154: get_weight=8'shed; 10'd155: get_weight=8'shf1;
        10'd156: get_weight=8'sh17; 10'd157: get_weight=8'sh31; 10'd158: get_weight=8'shf6; 10'd159: get_weight=8'shf9;
        10'd160: get_weight=8'sh0d; 10'd161: get_weight=8'she3; 10'd162: get_weight=8'shfc; 10'd163: get_weight=8'sh31;
        10'd164: get_weight=8'sh1b; 10'd165: get_weight=8'shdb; 10'd166: get_weight=8'she5; 10'd167: get_weight=8'shfe;
        10'd168: get_weight=8'sh21; 10'd169: get_weight=8'sh61; 10'd170: get_weight=8'shf3; 10'd171: get_weight=8'shdf;
        10'd172: get_weight=8'sh22; 10'd173: get_weight=8'shda; 10'd174: get_weight=8'sh12; 10'd175: get_weight=8'sh3c;
        10'd176: get_weight=8'sh05; 10'd177: get_weight=8'shd3; 10'd178: get_weight=8'sh16; 10'd179: get_weight=8'shf2;
        10'd180: get_weight=8'shff; 10'd181: get_weight=8'sh5c; 10'd182: get_weight=8'sh03; 10'd183: get_weight=8'shea;
        10'd184: get_weight=8'sh23; 10'd185: get_weight=8'sh07; 10'd186: get_weight=8'sh19; 10'd187: get_weight=8'sh4c;
        10'd188: get_weight=8'sheb; 10'd189: get_weight=8'sh12; 10'd190: get_weight=8'sh43; 10'd191: get_weight=8'shb0;

        // --- Neuron 4 ---
        10'd192: get_weight=8'shaa; 10'd193: get_weight=8'sh91; 10'd194: get_weight=8'shee; 10'd195: get_weight=8'sh80;
        10'd196: get_weight=8'sh93; 10'd197: get_weight=8'shf1; 10'd198: get_weight=8'shbb; 10'd199: get_weight=8'sh8b;
        10'd200: get_weight=8'shc2; 10'd201: get_weight=8'shb8; 10'd202: get_weight=8'sh80; 10'd203: get_weight=8'shd0;
        10'd204: get_weight=8'sh2b; 10'd205: get_weight=8'shc0; 10'd206: get_weight=8'shde; 10'd207: get_weight=8'sh25;
        10'd208: get_weight=8'shdb; 10'd209: get_weight=8'sh1d; 10'd210: get_weight=8'sh1f; 10'd211: get_weight=8'sh14;
        10'd212: get_weight=8'shc9; 10'd213: get_weight=8'sh15; 10'd214: get_weight=8'shcb; 10'd215: get_weight=8'shf7;
        10'd216: get_weight=8'sh1b; 10'd217: get_weight=8'she5; 10'd218: get_weight=8'sh1c; 10'd219: get_weight=8'sh24;
        10'd220: get_weight=8'shf7; 10'd221: get_weight=8'sh1b; 10'd222: get_weight=8'sh28; 10'd223: get_weight=8'shd9;
        10'd224: get_weight=8'sh15; 10'd225: get_weight=8'sh23; 10'd226: get_weight=8'sh9b; 10'd227: get_weight=8'sh4d;
        10'd228: get_weight=8'sh44; 10'd229: get_weight=8'shb5; 10'd230: get_weight=8'sh1f; 10'd231: get_weight=8'sh3c;
        10'd232: get_weight=8'shf3; 10'd233: get_weight=8'shaf; 10'd234: get_weight=8'sh35; 10'd235: get_weight=8'shd3;
        10'd236: get_weight=8'shb0; 10'd237: get_weight=8'sh3c; 10'd238: get_weight=8'shf2; 10'd239: get_weight=8'shd2;

        // --- Neuron 5 ---
        10'd240: get_weight=8'shc4; 10'd241: get_weight=8'shba; 10'd242: get_weight=8'sh37; 10'd243: get_weight=8'shc0;
        10'd244: get_weight=8'shf1; 10'd245: get_weight=8'sh29; 10'd246: get_weight=8'shc5; 10'd247: get_weight=8'shfe;
        10'd248: get_weight=8'sh25; 10'd249: get_weight=8'shb5; 10'd250: get_weight=8'shea; 10'd251: get_weight=8'sh7f;
        10'd252: get_weight=8'she9; 10'd253: get_weight=8'shed; 10'd254: get_weight=8'sh29; 10'd255: get_weight=8'shde;
        10'd256: get_weight=8'she2; 10'd257: get_weight=8'sh15; 10'd258: get_weight=8'shdd; 10'd259: get_weight=8'sh09;
        10'd260: get_weight=8'sh21; 10'd261: get_weight=8'shc1; 10'd262: get_weight=8'sh0c; 10'd263: get_weight=8'sh4e;
        10'd264: get_weight=8'shf5; 10'd265: get_weight=8'sh33; 10'd266: get_weight=8'shf4; 10'd267: get_weight=8'shbc;
        10'd268: get_weight=8'shfb; 10'd269: get_weight=8'sh05; 10'd270: get_weight=8'shd0; 10'd271: get_weight=8'sh0b;
        10'd272: get_weight=8'shff; 10'd273: get_weight=8'shad; 10'd274: get_weight=8'shfa; 10'd275: get_weight=8'shee;
        10'd276: get_weight=8'sh06; 10'd277: get_weight=8'sh50; 10'd278: get_weight=8'shf1; 10'd279: get_weight=8'sheb;
        10'd280: get_weight=8'sh18; 10'd281: get_weight=8'sh24; 10'd282: get_weight=8'shf0; 10'd283: get_weight=8'sh25;
        10'd284: get_weight=8'shf4; 10'd285: get_weight=8'shf5; 10'd286: get_weight=8'sh16; 10'd287: get_weight=8'shad;

        // --- Neuron 6 ---
        10'd288: get_weight=8'sh82; 10'd289: get_weight=8'sh80; 10'd290: get_weight=8'she3; 10'd291: get_weight=8'sh80;
        10'd292: get_weight=8'sh80; 10'd293: get_weight=8'sh03; 10'd294: get_weight=8'sh97; 10'd295: get_weight=8'sh80;
        10'd296: get_weight=8'sh14; 10'd297: get_weight=8'sh82; 10'd298: get_weight=8'sh93; 10'd299: get_weight=8'sh26;
        10'd300: get_weight=8'shd4; 10'd301: get_weight=8'sh80; 10'd302: get_weight=8'sh1f; 10'd303: get_weight=8'she3;
        10'd304: get_weight=8'shaa; 10'd305: get_weight=8'sh12; 10'd306: get_weight=8'shfd; 10'd307: get_weight=8'she6;
        10'd308: get_weight=8'sh2e; 10'd309: get_weight=8'she5; 10'd310: get_weight=8'sh1c; 10'd311: get_weight=8'sh31;
        10'd312: get_weight=8'shf9; 10'd313: get_weight=8'sh80; 10'd314: get_weight=8'sh15; 10'd315: get_weight=8'sh03;
        10'd316: get_weight=8'sh95; 10'd317: get_weight=8'shee; 10'd318: get_weight=8'shfb; 10'd319: get_weight=8'shd2;
        10'd320: get_weight=8'sh14; 10'd321: get_weight=8'she9; 10'd322: get_weight=8'shd7; 10'd323: get_weight=8'shf0;
        10'd324: get_weight=8'shdb; 10'd325: get_weight=8'sh94; 10'd326: get_weight=8'sh15; 10'd327: get_weight=8'she9;
        10'd328: get_weight=8'shd8; 10'd329: get_weight=8'sh49; 10'd330: get_weight=8'shcd; 10'd331: get_weight=8'shdf;
        10'd332: get_weight=8'sh3c; 10'd333: get_weight=8'shd2; 10'd334: get_weight=8'sheb; 10'd335: get_weight=8'sh16;

        // --- Neuron 7 ---
        10'd336: get_weight=8'sh62; 10'd337: get_weight=8'sh71; 10'd338: get_weight=8'sh1f; 10'd339: get_weight=8'sh3a;
        10'd340: get_weight=8'sh5e; 10'd341: get_weight=8'shce; 10'd342: get_weight=8'sh53; 10'd343: get_weight=8'sh5b;
        10'd344: get_weight=8'shde; 10'd345: get_weight=8'sh49; 10'd346: get_weight=8'sh55; 10'd347: get_weight=8'shbd;
        10'd348: get_weight=8'sh20; 10'd349: get_weight=8'sh3c; 10'd350: get_weight=8'sh16; 10'd351: get_weight=8'shff;
        10'd352: get_weight=8'sh1d; 10'd353: get_weight=8'shc6; 10'd354: get_weight=8'sh1f; 10'd355: get_weight=8'sh43;
        10'd356: get_weight=8'shbd; 10'd357: get_weight=8'sh19; 10'd358: get_weight=8'sh5a; 10'd359: get_weight=8'she7;
        10'd360: get_weight=8'sh2c; 10'd361: get_weight=8'sh2c; 10'd362: get_weight=8'sh01; 10'd363: get_weight=8'she9;
        10'd364: get_weight=8'shf7; 10'd365: get_weight=8'she3; 10'd366: get_weight=8'sh1e; 10'd367: get_weight=8'shec;
        10'd368: get_weight=8'sh0f; 10'd369: get_weight=8'sh20; 10'd370: get_weight=8'sh10; 10'd371: get_weight=8'sh04;
        10'd372: get_weight=8'sh30; 10'd373: get_weight=8'sh35; 10'd374: get_weight=8'shc2; 10'd375: get_weight=8'sh2d;
        10'd376: get_weight=8'sh05; 10'd377: get_weight=8'sh87; 10'd378: get_weight=8'sh33; 10'd379: get_weight=8'shbb;
        10'd380: get_weight=8'sh96; 10'd381: get_weight=8'sh53; 10'd382: get_weight=8'sh80; 10'd383: get_weight=8'sha5;

        // --- Neuron 8 ---
        10'd384: get_weight=8'shbe; 10'd385: get_weight=8'shd1; 10'd386: get_weight=8'sh15; 10'd387: get_weight=8'shf3;
        10'd388: get_weight=8'she0; 10'd389: get_weight=8'sh12; 10'd390: get_weight=8'sh01; 10'd391: get_weight=8'shfa;
        10'd392: get_weight=8'sh1f; 10'd393: get_weight=8'sh08; 10'd394: get_weight=8'sh16; 10'd395: get_weight=8'sh1d;
        10'd396: get_weight=8'shf2; 10'd397: get_weight=8'shd0; 10'd398: get_weight=8'sh1b; 10'd399: get_weight=8'shfd;
        10'd400: get_weight=8'shc4; 10'd401: get_weight=8'sh13; 10'd402: get_weight=8'she3; 10'd403: get_weight=8'sh00;
        10'd404: get_weight=8'sh21; 10'd405: get_weight=8'shec; 10'd406: get_weight=8'she2; 10'd407: get_weight=8'sh23;
        10'd408: get_weight=8'shed; 10'd409: get_weight=8'shd2; 10'd410: get_weight=8'she2; 10'd411: get_weight=8'sh00;
        10'd412: get_weight=8'shcc; 10'd413: get_weight=8'shfa; 10'd414: get_weight=8'shf8; 10'd415: get_weight=8'shd1;
        10'd416: get_weight=8'sh03; 10'd417: get_weight=8'shdc; 10'd418: get_weight=8'sh8f; 10'd419: get_weight=8'shfb;
        10'd420: get_weight=8'shec; 10'd421: get_weight=8'shca; 10'd422: get_weight=8'she2; 10'd423: get_weight=8'shf9;
        10'd424: get_weight=8'shc9; 10'd425: get_weight=8'sh28; 10'd426: get_weight=8'shd6; 10'd427: get_weight=8'shbc;
        10'd428: get_weight=8'sh23; 10'd429: get_weight=8'shbe; 10'd430: get_weight=8'sh80; 10'd431: get_weight=8'she2;

        // --- Neuron 9 ---
        10'd432: get_weight=8'shbb; 10'd433: get_weight=8'shb8; 10'd434: get_weight=8'shfc; 10'd435: get_weight=8'sh19;
        10'd436: get_weight=8'shee; 10'd437: get_weight=8'shfa; 10'd438: get_weight=8'sh14; 10'd439: get_weight=8'sh09;
        10'd440: get_weight=8'sh18; 10'd441: get_weight=8'sh15; 10'd442: get_weight=8'sh37; 10'd443: get_weight=8'sh18;
        10'd444: get_weight=8'shf4; 10'd445: get_weight=8'shbc; 10'd446: get_weight=8'shfa; 10'd447: get_weight=8'sh1f;
        10'd448: get_weight=8'shf0; 10'd449: get_weight=8'sh19; 10'd450: get_weight=8'shfc; 10'd451: get_weight=8'sh18;
        10'd452: get_weight=8'she4; 10'd453: get_weight=8'sh17; 10'd454: get_weight=8'sh20; 10'd455: get_weight=8'shc9;
        10'd456: get_weight=8'sh11; 10'd457: get_weight=8'she0; 10'd458: get_weight=8'sh0a; 10'd459: get_weight=8'sh1a;
        10'd460: get_weight=8'she2; 10'd461: get_weight=8'sh2d; 10'd462: get_weight=8'sh00; 10'd463: get_weight=8'shfa;
        10'd464: get_weight=8'sh03; 10'd465: get_weight=8'shff; 10'd466: get_weight=8'she7; 10'd467: get_weight=8'shd5;
        10'd468: get_weight=8'sh21; 10'd469: get_weight=8'she5; 10'd470: get_weight=8'shd5; 10'd471: get_weight=8'sh40;
        10'd472: get_weight=8'shf8; 10'd473: get_weight=8'shc0; 10'd474: get_weight=8'sh38; 10'd475: get_weight=8'sh01;
        10'd476: get_weight=8'shaf; 10'd477: get_weight=8'sh55; 10'd478: get_weight=8'shc3; 10'd479: get_weight=8'sh9d;
        default: get_weight = 8'sh00;
    endcase
endfunction


    reg signed [7:0] temp_bias;
    

// =========================================================
    // [블록 1] 제어 및 연산 로직 (Reset 필요함)
    // state, counter, mac_sum, 가중치 계산은 여기서 합니다.
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            buffer_cnt   <= 0;
            valid_out_fc <= 0;
            neuron_idx   <= 0;
            mac_idx      <= 0;
            mac_sum      <= 0;
            find_max_cnt <= 0;
            max_val      <= 32'sh80000000;
            final_result <= 0;
            result_leds  <= 0;
            
        end else begin
            case (state)
                S_IDLE: begin
                    buffer_cnt   <= 0;
                    neuron_idx   <= 0;
                    mac_idx      <= 0;
                    mac_sum      <= 0;
                    valid_out_fc <= 0;
                    find_max_cnt <= 0;
                    max_val      <= 32'sh80000000;
                    
                    if (valid_in) begin
                        state      <= S_BUFFERING;
                        buffer_cnt <= 1; 
                    end
                end 

                S_BUFFERING: begin
                    if (valid_in) begin
                        // input_buffer 넣는 코드는 아래 [블록 2]로 이사 갔습니다.
                        
                        if (buffer_cnt == 15) begin
                            buffer_cnt <= 0;
                            state      <= S_CALC;
                        end else begin
                            buffer_cnt <= buffer_cnt + 1;
                        end
                    end
                end
                
                S_CALC: begin
                    if (mac_idx < 48) begin
                         // [중요] 가중치 계산 로직은 여기 그대로 둡니다! (잘 하셨습니다)
                         // input_buffer 값을 읽는 것은(Reading) 여기서 해도 됩니다. (Writing만 분리)
                         mac_sum <= mac_sum + ($signed(input_buffer[mac_idx]) * $signed(get_weight(neuron_idx * 48 + mac_idx)));
                         mac_idx <= mac_idx + 1;
                    end else begin
                        temp_bias = get_bias(neuron_idx);
                        neuron_outputs[neuron_idx] <= (mac_sum >>> 7) + $signed(temp_bias);
                        
                        mac_idx <= 0;
                        mac_sum <= 0;
                        
                        if (neuron_idx == 9) begin
                            state        <= S_FIND_MAX;
                            max_val      <= 32'sh80000000; 
                            find_max_cnt <= 0;
                        end else begin
                            neuron_idx <= neuron_idx + 1;
                        end      
                    end
                end

                S_FIND_MAX: begin
                    if (find_max_cnt < 10) begin
                        if ($signed(neuron_outputs[find_max_cnt]) > $signed(max_val)) begin
                            max_val      <= neuron_outputs[find_max_cnt];
                            final_result <= find_max_cnt;
                        end
                        find_max_cnt <= find_max_cnt + 1;
                    end else begin
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    valid_out_fc <= 1'b1;
                    result_leds  <= final_result;
                    
                    if (valid_in) begin 
                        state        <= S_BUFFERING;
                        valid_out_fc <= 0;
                        find_max_cnt <= 0;
                        max_val      <= 32'sh80000000;
                        neuron_idx   <= 0;
                        buffer_cnt   <= 1; 
                    end
                end
            endcase
        end
    end
 
    always @(posedge clk) begin
        if (valid_in) begin
            // 1. 처음 시작할 때 (IDLE 또는 DONE)
            if (state == S_IDLE || state == S_DONE) begin
                input_buffer[0] <= $signed(data_in_1);
                input_buffer[1] <= $signed(data_in_2);
                input_buffer[2] <= $signed(data_in_3);
            end
            // 2. 버퍼링 중일 때
            else if (state == S_BUFFERING) begin
                input_buffer[buffer_cnt * 3]     <= $signed(data_in_1);
                input_buffer[buffer_cnt * 3 + 1] <= $signed(data_in_2);
                input_buffer[buffer_cnt * 3 + 2] <= $signed(data_in_3);
            end
        end
    end
endmodule
