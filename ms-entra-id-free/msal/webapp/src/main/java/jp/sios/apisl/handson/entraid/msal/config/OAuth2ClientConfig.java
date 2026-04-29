package jp.sios.apisl.handson.entraid.msal.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.security.oauth2.client.AuthorizedClientServiceOAuth2AuthorizedClientManager;
import org.springframework.security.oauth2.client.InMemoryOAuth2AuthorizedClientService;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientManager;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientProvider;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientProviderBuilder;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.DefaultOAuth2AuthorizedClientManager;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizedClientRepository;

@Configuration
public class OAuth2ClientConfig {

    /**
     * 【標準マネージャー】
     * Authorization Code Flow 用（Redis/Session連動）
     * @Primary を付けることで @RegisteredOAuth2AuthorizedClient アノテーションがこちらを使用します
     */
    @Bean
    @Primary
    public OAuth2AuthorizedClientManager authorizedClientManager(
            ClientRegistrationRepository clientRegistrationRepository,
            OAuth2AuthorizedClientRepository authorizedClientRepository) {

        DefaultOAuth2AuthorizedClientManager manager = 
            new DefaultOAuth2AuthorizedClientManager(clientRegistrationRepository, authorizedClientRepository);

        OAuth2AuthorizedClientProvider provider = OAuth2AuthorizedClientProviderBuilder.builder()
                .authorizationCode()
                .refreshToken()
                .build();
        manager.setAuthorizedClientProvider(provider);

        return manager;
    }

    /**
     * 【M2M専用マネージャー】
     * Client Credentials Flow 用（メモリ管理 / セッション非依存）
     */
    @Bean(name = "m2mAuthorizedClientManager")
    public OAuth2AuthorizedClientManager m2mAuthorizedClientManager(
            ClientRegistrationRepository clientRegistrationRepository) {

        InMemoryOAuth2AuthorizedClientService memoryService = 
            new InMemoryOAuth2AuthorizedClientService(clientRegistrationRepository);

        AuthorizedClientServiceOAuth2AuthorizedClientManager manager = 
            new AuthorizedClientServiceOAuth2AuthorizedClientManager(clientRegistrationRepository, memoryService);

        OAuth2AuthorizedClientProvider provider = OAuth2AuthorizedClientProviderBuilder.builder()
                .clientCredentials()
                .build();
        manager.setAuthorizedClientProvider(provider);

        return manager;
    }
}