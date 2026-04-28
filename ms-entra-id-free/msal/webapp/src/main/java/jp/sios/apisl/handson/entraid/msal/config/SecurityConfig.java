package jp.sios.apisl.handson.entraid.msal.config;

import static org.springframework.security.config.Customizer.withDefaults;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.session.data.redis.config.annotation.web.http.EnableRedisHttpSession;

@Configuration
@EnableRedisHttpSession(maxInactiveIntervalInSeconds = 28800) // 8時間
public class SecurityConfig {
	@Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
		http.authorizeHttpRequests(auth -> auth
                // 認証必須のURIを指定
                .requestMatchers("/hands-on").authenticated()
                .anyRequest().permitAll()
            )
            // OAuth2有効
            .oauth2Login(withDefaults())
			// Logoutの設定
			.logout(logout -> logout
                // GETリクエスト（リンク）でログアウト許可設定
                .logoutUrl("/logout")
                .logoutSuccessUrl("/hands-on")
                .deleteCookies("JSESSIONID")
                .invalidateHttpSession(true)
            );

        return http.build();
	}	
}
