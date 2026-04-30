package jp.sios.apisl.handson.entraid.msal.controller;

import com.microsoft.aad.msal4j.ClientCredentialFactory;
import com.microsoft.aad.msal4j.ClientCredentialParameters;
import com.microsoft.aad.msal4j.ConfidentialClientApplication;
import com.microsoft.aad.msal4j.IAuthenticationResult;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.annotation.RegisteredOAuth2AuthorizedClient;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import java.util.HashSet;
import java.util.List;

@Controller
public class HandsonController {

    @Value("${spring.cloud.azure.active-directory.credential.client-id}")
    private String clientId;

    @Value("${spring.cloud.azure.active-directory.credential.client-secret}")
    private String clientSecret;

    @Value("${spring.cloud.azure.active-directory.authorization-clients.my-client-m2m.authority-uri}")
    private String authorityUri;

    @Value("${spring.cloud.azure.active-directory.authorization-clients.my-client-m2m.scopes}")
    private List<String> m2mScopes;

	@GetMapping("/hands-on/authorization-code")
	public String authorizationCodeFlow(
			@RegisteredOAuth2AuthorizedClient("my-client-u2m") OAuth2AuthorizedClient authorizedClient,
			@AuthenticationPrincipal OidcUser oidcUser,
			Model model) {

		String accessToken = authorizedClient.getAccessToken().getTokenValue();
		String refreshToken = (authorizedClient.getRefreshToken() != null) 
                ? authorizedClient.getRefreshToken().getTokenValue() 
                : "Could not obtain a refresh token (please check if `offline_access` is included in the scope).";
		String idToken = oidcUser.getIdToken().getTokenValue();
		String userName = oidcUser.getFullName();

		model.addAttribute("accessToken", accessToken);
        model.addAttribute("refreshToken", refreshToken);
        model.addAttribute("idToken", idToken);
        model.addAttribute("userName", userName);

		return "authorization-code";
	}

	@GetMapping("/hands-on/client-credentials")
    public String clientCredentialsFlow(Model model) throws Exception {

        // MSAL4J を使って直接トークンを要求
        ConfidentialClientApplication app = ConfidentialClientApplication.builder(
                clientId,
                ClientCredentialFactory.createFromSecret(clientSecret))
                .authority(authorityUri)
                .build();
        ClientCredentialParameters parameters = ClientCredentialParameters.builder(
                new HashSet<>(m2mScopes))
                .build();

        // トークンの取得
        IAuthenticationResult result = app.acquireToken(parameters).join();
        String accessToken = result.accessToken();

        String refreshToken = "Client Credentials flow does not issue refresh tokens.";        
        String idToken = "Client Credentials flow does not issue ID tokens (No user involved).";
		String userName = "System (Application Identity)";

        model.addAttribute("accessToken", accessToken);
        model.addAttribute("refreshToken", refreshToken);
        model.addAttribute("idToken", idToken);
        model.addAttribute("userName", userName);

        return "client-credentials";
    }
}