package com.music.bitchord.ios

import com.metrolist.innertubex.InnerTube
import com.metrolist.innertubex.InnerTubeLogger
import com.metrolist.innertubex.cipher.PlayerConfigRepository
import com.metrolist.innertubex.cipher.RemotePlayerConfigStore
import com.metrolist.innertubex.cipher.YouTubeCipherService
import com.metrolist.innertubex.extraction.AudioQuality
import com.metrolist.innertubex.extraction.ContentHints
import com.metrolist.innertubex.extraction.InnerTubeExtractor
import com.metrolist.innertubex.extraction.YtConfigParserImpl
import com.metrolist.innertubex.extraction.generateClientPlaybackNonce
import com.metrolist.innertubex.models.YouTubeLocale
import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json

class IOSResolvedStream(
    val url: String,
    val mimeType: String,
    val headers: Map<String, String>,
)

class IOSStreamResolver {
    private val httpClient = HttpClient(Darwin) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; explicitNulls = false })
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 20_000
        }
        expectSuccess = false
    }
    private val logger = InnerTubeLogger.NONE
    private val innerTube = InnerTube(httpClient, logger = logger)
    private val playerConfigStore = RemotePlayerConfigStore(
        httpClient,
        PlayerConfigRepository.disabled(),
        logger,
    )
    private val cipherService = YouTubeCipherService(httpClient, playerConfigStore, logger)
    private val configParser = YtConfigParserImpl(
        httpClient,
        innerTube,
        playerConfigStore,
        logger,
    )
    private val extractor = InnerTubeExtractor(
        configParser = configParser,
        cipherService = cipherService,
        innerTube = innerTube,
        logger = logger,
    )
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun resolve(
        videoId: String,
        region: String,
        language: String,
        completion: (IOSResolvedStream?, String?) -> Unit,
    ) {
        scope.launch {
            try {
                innerTube.locale = YouTubeLocale(gl = region, hl = language)
                if (innerTube.visitorData.isNullOrBlank()) {
                    innerTube.visitorData = innerTube.fetchFreshVisitorData()
                }
                val stream = extractor.extract(
                    videoId = videoId,
                    hints = ContentHints().withStreamCapabilities(
                        allowHls = false,
                        allowSabr = false,
                        allowBoundedRange = true,
                    ),
                    excludedClients = emptySet(),
                    audioQuality = AudioQuality.MP4,
                    clientPlaybackNonce = generateClientPlaybackNonce(),
                ) ?: error("YouTube did not provide a playable audio stream.")
                check(stream.sabrBootstrap == null) {
                    "This stream uses a format the iOS player cannot play."
                }
                val result = IOSResolvedStream(
                    url = stream.audioUrl,
                    mimeType = stream.mimeType.orEmpty(),
                    headers = stream.headers,
                )
                withContext(Dispatchers.Main) {
                    completion(result, null)
                }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                withContext(Dispatchers.Main) {
                    completion(null, error.message ?: "Unable to resolve this YouTube Music stream.")
                }
            }
        }
    }
}
