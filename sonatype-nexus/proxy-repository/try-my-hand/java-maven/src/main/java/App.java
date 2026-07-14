import org.apache.commons.lang3.StringUtils;

public class App {
    public static void main(String[] args) {
        System.out.println("==========================================");
        System.out.println("   Java (Maven) Repository Manager Demo   ");
        System.out.println("==========================================");

        String[] words = {"hello", "world", "nexus", "maven"};
        for (String word : words) {
            System.out.println("  " + StringUtils.capitalize(word));
        }

        System.out.println("==========================================");
    }
}
