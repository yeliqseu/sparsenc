#ifndef SNC_H
#define SNC_H
#ifndef GALOIS
#define GALOIS
typedef unsigned char GF_ELEMENT;
#endif
/*
 * Type of SNC codes
 * RAND     - Packets are pesudo-randomly grouped
 * BAND     - Packets are grouped to be consecutively overlapped
 * WINDWRAP - Similar as BAND, but has wrap around in encoding vectors
 * BATS     - Fixed-degree Batch Sparse Code
 */
#define RAND_SNC        0
#define BAND_SNC        1
#define WINDWRAP_SNC    2
#define BATS_SNC        3
#define RAPTOR_SNC      99

/*
 * Type of SNC decoders
 * GG  - (Sub)Generation-by-(sub)generation decoder
 * OA  - Overlap aware decoder
 * BD  - Band decoder with pivoting
 * CBD - Compact band decoder with compact decoding matrix representation
 */
#define GG_DECODER  0
#define OA_DECODER  1
#define BD_DECODER  2
#define CBD_DECODER 3
#define PP_DECODER  4

/*
 * Type of scheduling algorithms for SNC recoding
 * TRIV - Schedule with trivally randomly (even schedule an empty buffer)
 * RAND - Randomly schedule generations with non-empty buffer
 * MLPI - Maximum Local Potential Innovativeness scheduling
 */
#define TRIV_SCHED      0
#define RAND_SCHED      1
#define RAND_SCHED_SYS  2
#define MLPI_SCHED      3
#define MLPI_SCHED_SYS  4
#define NURAND_SCHED    5

struct snc_context;     // Sparse network code encode context

struct snc_packet {
    int         gid;    // subgeneration/batch id;
    int         ucid;   // it's an uncoded packet of THE GENERATION 
                        // (note: not the packet index; -1 if it's coded)
    GF_ELEMENT  *coes;  // SIZE_G coding coefficients of coded packet
    GF_ELEMENT  *syms;  // SIZE_P symbols of coded packet
};

// SNC parameters for the data to be snc-coded
struct snc_parameters {
    long    datasize;   // Data size in bytes.
    int     size_p;     // packet size (in bytes)
    int     size_c;     // number of parity-check
    int     size_b;     // base subgeneration size of fixed-number subset codes or the BTS for BATS-like codes
    int     size_g;     // subgeneration size
    int     type;       // Code type
    int     bpc;        // binary precode or GF(256) precode
    int     gfpower;    // Power of Galois field for NC, supports {1,2,...,8}, i.e., GF(2),...,GF(256)
    int     sys;        // systematic code
    int     seed;       // seed of local RNG
};

struct snc_decoder;     // Sparse network code decoder

struct snc_buffer;      // Buffer for storing snc packets

struct snc_buffer_bats;

/*------------------------------- sncEncoder -------------------------------*/
/**
 * Create encode context from a message buffer pointed by buf. Code parameters
 * are provided in sp.
 *
 * Return Values:
 *   On success, a pointer to the allocated encode context is returned;
 *   On error, NULL is returned, and errno is set appropriately.
 **/
struct snc_context *snc_create_enc_context(unsigned char *buf, struct snc_parameters *sp);

// Get code parameters of an encode context
struct snc_parameters *snc_get_parameters(struct snc_context *sc);

// Load file content into encode context
int snc_load_file_to_context(const char *filepath, long start, struct snc_context *sc);

// Free up encode context
void snc_free_enc_context(struct snc_context *sc);

// Restore data in the encode context to a char buffer
unsigned char *snc_recover_data(struct snc_context *sc);

// Free the buffer of the recovered data
void snc_free_recovered(unsigned char *data);

// Restore data in the encode context to a file (append if file exists)
long snc_recover_to_file(const char *filepath, struct snc_context *sc);

// Allocate an snc packet with coes and syms being zero
struct snc_packet *snc_alloc_empty_packet(struct snc_parameters *sp);

// Length of serialized snc_packet (unit: bytes)
int snc_packet_length(struct snc_parameters *param);

// Serialize snc_packet to a byte buffer
unsigned char *snc_serialize_packet(struct snc_packet *pkt, struct snc_parameters *param);

// De-serialize packet string to a snc_packet struct
struct snc_packet *snc_deserialize_packet(unsigned char *pktstr, struct snc_parameters *param);

// Generate an snc packet from the encode context
struct snc_packet *snc_generate_packet(struct snc_context *sc);

// Duplicate an snc packet
struct snc_packet *snc_duplicate_packet(struct snc_packet *pkt, struct snc_parameters *params);

// Generate an snc packet to the memory of an existing snc_packet struct
int snc_generate_packet_im(struct snc_context *sc, struct snc_packet *pkt);

// Free up an snc packet
void snc_free_packet(struct snc_packet *pkt);

// Print encode/decode summary of an snc (for benchmarking)
void print_code_summary(struct snc_context *sc, double overhead, double operations);

// Return the power of the finite field size used by the code (for performance tuning)
int snc_get_GF_power(struct snc_parameters *sp);

/*------------------------------- sncDecoder -------------------------------*/
/**
 * Create an snc decoder given code parameter and decoder type
 *   4 decoders are supported:
 *      GG_DECODER
 *      OA_DECODER
 *      BD_DECODER
 *      CBD_DECODER
 */
struct snc_decoder *snc_create_decoder(struct snc_parameters *sp, int d_type);

// Get the encode context that the decoder is working on/finished.
struct snc_context *snc_get_enc_context(struct snc_decoder *decoder);

// Feed decoder with an snc packet
void snc_process_packet(struct snc_decoder *decoder, struct snc_packet *pkt);

// Check whether the decoder is finished
int snc_decoder_finished(struct snc_decoder *decoder);

// Return the current number of the received innovative packets (a.k.a. degree of freedom, dof)
int snc_get_decoder_dof(struct snc_decoder *decoder);

// Return decode overhead, which is defined as oh = N / M, where
//   N - Number of received packets to successfully decode
//   M - Number of source packets
double snc_decode_overhead(struct snc_decoder *decoder);

// Return decode cost, which is defined as N_ops/M/K, where
//   N_ops - Number of total finite field operations during decoding
//   M     - Number of source packets
//   K     - Number of symbols of each source pacekt
double snc_decode_cost(struct snc_decoder *decoder);

// Free decoder memory
void snc_free_decoder(struct snc_decoder *decoder);

// Save decoder context into a file
long snc_save_decoder_context(struct snc_decoder *decoder, const char *filepath);

// Restore decoder from the context stored in a file
struct snc_decoder *snc_restore_decoder(const char *filepath);

/*----------------------------- sncRecoder ------------------------------*/
/**
 * Create a buffer for storing snc packets.
 *   Arguments:
 *     snc_parameters - parameters of the snc code
 *     bufsize        - buffer size of each subgeneration
 *   Return Value:
 *     Pointer to the buffer on success; NULL on error
 **/
struct snc_buffer *snc_create_buffer(struct snc_parameters *sp, int bufsize);

// Save an snc packet to an snc buffer
void snc_buffer_packet(struct snc_buffer *buffer, struct snc_packet *pkt);

// Recode an snc packet from an snc buffer
struct snc_packet *snc_recode_packet(struct snc_buffer *buffer, int sched_t);

// Recode a packet from an snc buffer to an allocated snc_packet struct
int snc_recode_packet_im(struct snc_buffer *buffer, struct snc_packet *pkt, int sched_t);

// Free snc buffer
void snc_free_buffer(struct snc_buffer *buffer);

/*---------------------------- sncRecoderBATS ----------------------------*/

struct snc_buffer_bats *snc_create_buffer_bats(struct snc_parameters *sp, int bufsize);

void snc_buffer_packet_bats(struct snc_buffer_bats *buf, struct snc_packet *pkt);

struct snc_packet *snc_recode_packet_bats(struct snc_buffer_bats *buf);

int snc_recode_packet_bats_im(struct snc_buffer_bats *buf, struct snc_packet *pkt);

void snc_free_buffer_bats(struct snc_buffer_bats *buf);
#endif /* SNC_H */
